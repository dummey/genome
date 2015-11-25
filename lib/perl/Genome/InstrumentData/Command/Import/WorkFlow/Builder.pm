package Genome::InstrumentData::Command::Import::WorkFlow::Builder;

use strict;
use warnings;

use Genome;

require Genome::WorkflowBuilder::DAG;
require List::MoreUtils;
use Params::Validate ':types';

class Genome::InstrumentData::Command::Import::WorkFlow::Builder {
    is => 'UR::Object',
    is_abstract => 1,
    subclassify_by => 'format',
    has => {
        work_flow_inputs => { is => 'Genome::InstrumentData::Command::Import::WorkFlow::Inputs', },
        format => {
            calculate_from => [qw/ work_flow_inputs /],
            calculate => sub{ return join('::', __PACKAGE__, ucfirst($_[0]->format)); },
        },
    },
    has_optional_constant_calculated => {
        helpers => { calculate => q( Genome::InstrumentData::Command::Import::WorkFlow::Helpers->get; ), },
    },
    has_optional_transient => {
        _dag => {},
        _work_flow_ops => { is => 'HASH', default_value => {}, },
    },
};

sub _work_flow_op_for {
    my ($self, $name) = @_;
    return $self->_work_flow_ops->{$name};
}

sub build_workflow {
    my $self = shift;

    my $dag = Genome::WorkflowBuilder::DAG->create(name => 'Import Instrument Data');
    $self->_dag($dag);

    my @steps = $self->_steps_to_build_workflow;
    my $previous_op;
    for my $step ( @steps ) {
        my $add_step_method = join('_', '', 'add', split(' ', $step), 'op', 'to', 'workflow');
        my $op = $self->$add_step_method($previous_op);
        return if not $op;
        $self->_work_flow_ops->{$step} = $op;
        $previous_op = $op;
    }

    return $dag;
}

sub work_flow_operation_class_for_name {
    my ($name) = Params::Validate::validate_pos(@_, {is => SCALAR});
    die 'No name given to get work flow operation class!' if !@_;
    return 'Genome::InstrumentData::Command::Import::WorkFlow::'
        . join('', map { ucfirst } split(' ', $name));
}

sub _add_retrieve_source_path_op_to_workflow {
    my ($self, $previous_op) = @_;

    my $name = 'retrieve source path from '.$self->work_flow_inputs->source_files->retrieval_method;
    my $retrieve_source_path_op = Genome::WorkflowBuilder::Command->create(
        name => $name,
        command => work_flow_operation_class_for_name($name),
    );
    $self->_dag->add_operation($retrieve_source_path_op);
    $self->_dag->connect_input(
        input_property => 'working_directory',
        destination => $retrieve_source_path_op,
        destination_property => 'working_directory',
    );
    $self->_dag->connect_input(
        input_property => 'source_paths',
        destination => $retrieve_source_path_op,
        destination_property => 'source_path',
    );
    $retrieve_source_path_op->parallel_by('source_path') if $self->work_flow_inputs->source_files->paths > 1;

    return $retrieve_source_path_op;
}

sub _add_verify_not_imported_op_to_workflow {
    my ($self, $retrieve_source_path_op) = @_;

    die 'No retrieve source files operation given!' if not $retrieve_source_path_op;

    my $name = 'verify not imported';
    my $verify_not_imported_op = Genome::WorkflowBuilder::Command->create(
        name => $name,
        command => work_flow_operation_class_for_name($name),
    );
    $self->_dag->add_operation($verify_not_imported_op);
    $self->_dag->connect_input(
        input_property => 'working_directory',
        destination => $verify_not_imported_op,
        destination_property => 'working_directory',
    );
    $self->_dag->create_link(
        source => $retrieve_source_path_op,
        source_property => 'destination_path',
        destination => $verify_not_imported_op,
        destination_property => 'source_path',
    );
    $verify_not_imported_op->parallel_by('source_path') if $self->work_flow_inputs->source_files->paths > 1;

    return $verify_not_imported_op;
}

sub _add_sra_to_bam_op_to_workflow {
    my $self = shift;

    my $workflow = $self->_workflow;
    my $sra_to_bam_op = $self->helpers->add_operation_to_workflow_by_name($workflow, 'sra to bam');
    for my $property_mapping ( [qw/ working_directory working_directory /], [qw/ source_path sra_path /] ) {
        my ($left_property, $right_property) = @$property_mapping;
        $workflow->add_link(
            left_operation => $self->_work_flow_op_for('verify not imported'),
            left_property => $left_property,
            right_operation => $sra_to_bam_op,
            right_property => $right_property,
        );
    }

    return $sra_to_bam_op;
}

sub _add_sanitize_bam_op_to_workflow {
    my ($self, $previous_op) = @_;

    die 'No previous operation given to _add_sanitize_bam_op_to_workflow!' if not $previous_op;

    my $name = 'sanitize bam';
    my $sanitize_bam_op = Genome::WorkflowBuilder::Command->create(
        name => $name,
        command => work_flow_operation_class_for_name($name),
    );
    $self->_dag->add_operation($sanitize_bam_op);
    $self->_dag->create_link(
        source => $previous_op,
        source_property => 'output_bam_path',
        destination => $sanitize_bam_op,
        destination_property => 'bam_path',
    );

    return $sanitize_bam_op;
}

sub _add_sort_bam_op_to_workflow {
    my ($self, $previous_op) = @_;

    die 'No previous op given to _add_sort_bam_op_to_workflow!' if not $previous_op;

    my $name = 'sort bam';
    my $sort_bam_op = Genome::WorkflowBuilder::Command->create(
        name => $name,
        command => work_flow_operation_class_for_name($name),
    );
    $self->_dag->add_operation($sort_bam_op);
    $self->_dag->create_link(
        source => $previous_op,
        source_property => ( $previous_op->command->can('output_bam_path') )
        ? 'output_bam_path'
        : 'source_path',
        destination => $sort_bam_op,
        destination_property => 'bam_path',
    );

    return $sort_bam_op;
}

sub _add_downsample_bam_op_to_workflow {
    my ($self, $previous_op) = @_;

    die 'No previous op given to _add_downsample_bam_op_to_workflow!' if not $previous_op;

    my $downsample_bam_op = $self->helpers->add_operation_to_workflow_by_name($self->_workflow, 'downsample bam');
    return if not $downsample_bam_op;

    $self->_workflow->add_link(
        left_operation => $self->_workflow->get_input_connector,
        left_property => 'downsample_ratio',
        right_operation => $downsample_bam_op,
        right_property => 'downsample_ratio',
    );
    $self->_workflow->add_link(
        left_operation => $previous_op,
        left_property => 'output_bam_path',
        right_operation => $downsample_bam_op,
        right_property => 'bam_path',
    );

    return $downsample_bam_op;
}

sub _add_split_bam_by_rg_op_to_workflow {
    my ($self, $previous_op) = @_;

    die 'No previous op given to _add_split_bam_by_rg_op_to_workflow!' if not $previous_op;

    my $name = 'split bam by read group';
    my $split_bam_by_rg_op = Genome::WorkflowBuilder::Command->create(
        name => $name,
        command => work_flow_operation_class_for_name($name),
    );
    $self->_dag->add_operation($split_bam_by_rg_op);
    $self->_dag->create_link(
        source => $previous_op,
        source_property => 'output_bam_path',
        destination => $split_bam_by_rg_op,
        destination_property => 'bam_path',
    );

    return $split_bam_by_rg_op;
}

sub _add_create_instrument_data_op_to_workflow {
    my ($self, $previous_op) = @_;

    die 'No previous op given to _add_create_instrument_data_op_to_workflow!' if not $previous_op;

    my $name = 'create instrument data';
    my $create_instdata_op = Genome::WorkflowBuilder::Command->create(
        name => $name,
        command => work_flow_operation_class_for_name($name),
    );
    $self->_dag->add_operation($create_instdata_op);

    for my $property (qw/ analysis_project library instrument_data_properties /) {
        $self->_dag->connect_input(
            input_property => $property,
            destination => $create_instdata_op,
            destination_property => $property,
        );
    }

    $self->_dag->create_link(
        source => $previous_op,
        source_property => ( $previous_op->name eq 'sort bam' ) # not ideal...
        ? 'output_bam_path'
        : 'output_bam_paths',
        destination => $create_instdata_op,
        destination_property => 'bam_paths',
    );
    $self->_dag->create_link(
        source => $self->_work_flow_op_for('verify not imported'),
        source_property => 'source_md5',
        destination => $create_instdata_op,
        destination_property => 'source_md5s',
    );
    #$create_instdata_op->parallel_by('bam_paths');

    $self->_dag->connect_output(
        output_property => 'instrument_data',
        source => $create_instdata_op,
        source_property => 'instrument_data',
    );

    return $create_instdata_op;
}

1;

