package Genome::Test::Command::RunPteroIntegrationTests;

use strict;
use warnings FATAL => 'all';
use Genome;

use File::Basename qw(dirname basename);
use File::Spec qw();
use Test::Deep::NoTest qw(cmp_details deep_diag);
use Cwd qw(getcwd abs_path);
use JSON qw(from_json);
use Data::Dump qw(pp);

class Genome::Test::Command::RunPteroIntegrationTests {
    is => 'Genome::Command::WithColor',
    doc => "Run tests that submit small workflows to PTero",
    has_input => [
        test_pattern => {
            is => 'Text',
            is_optional => 1,
            default => '*',
            doc => 'Glob that will match directories and determine ' .
                'what tests to run',
        },
        log_directory => {
            is => 'Path',
            doc => 'Directory where logs from jobs in workflows will be ' .
                'written, must be accessible to shell-command and lsf workers',
        },
    ],
};

sub execute {
    my $self = shift;
    my $rv = 1;

    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    Genome::Config::set_env('workflow_builder_backend', 'ptero');

    my @test_directories = (glob test_data_directory($self->test_pattern));
    $self->status_message("Found test_pattern: %s so the following tests will run %s",
        $self->test_pattern, pp(@test_directories));

    for my $test_directory (@test_directories) {
        my $test_name = basename($test_directory);
        $self->status_message("Reading in workflow from directory: %s",
            test_data_directory($test_name));
        my $workflow = Genome::WorkflowBuilder::DAG->from_xml_filename(
            workflow_xml_file($test_name));

        my $log_dir = File::Spec->join($self->log_directory, $test_name);
        $workflow->recursively_set_log_dir($log_dir);

        $self->status_message($self->_color(
                "Executing workflow: $test_name", "cyan"));
        my $outputs = $workflow->execute(inputs => get_test_inputs($test_name),
            polling_interval => 2);
        my ($ok, $stack) = cmp_details($outputs, get_test_outputs($test_name));
        if ($ok) {
            $self->status_message("%s - Workflow %s produced expected output",
                $self->_color("PASS", "green"), $test_name);
        } else {
            $rv = 0;
            $self->status_message("%s - Workflow %s produced expected output",
                $self->_color("FAIL", "red"), $test_name);
            $self->status_message(deep_diag($stack));
        }
    }
    return $rv;
}

sub workflow_xml_file {
    my $name = shift;

    my $file = File::Spec->join(test_data_directory($name), 'workflow.xml');
    die "Cannot locate workflow.xml for workflow_test: $name" unless -e $file;
    return $file;
}

sub get_test_inputs {
    my $name = shift;
    my $file = File::Spec->join(test_data_directory($name), 'inputs.json');
    die "Cannot locate test inputs for workflow_test: $name" unless -e $file;
    return from_json(Genome::Sys->read_file($file));
}

sub get_test_outputs {
    my $name = shift;
    my $file = File::Spec->join(test_data_directory($name), 'outputs.json');
    die "Cannot locate test outputs for workflow_test: $name" unless -e $file;
    return from_json(Genome::Sys->read_file($file));
}

sub test_data_directory {
    my $name = shift;
    my $genome_dir = Genome->base_dir();

    return File::Spec->join($genome_dir, 'Ptero', 'workflow_tests', $name);
}

1;
