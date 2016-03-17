#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above "Genome";
use Test::More;
use Genome::Utility::Test qw(compare_ok);

Genome::Config::set_env('workflow_builder_backend', 'inline');

use_ok('Genome::Model::ClinSeq::Command::IdentifyLoh') or die;

#Define the test where expected results are stored
my $expected_output_dir =
Genome::Utility::Test->data_dir_ok(
    'Genome::Model::ClinSeq::Command::IdentifyLoh',
    '2015-05-15');
ok(-e $expected_output_dir, "Found test dir: $expected_output_dir") or die;

my $temp_dir = Genome::Sys->create_temp_directory();
ok($temp_dir, "created temp directory: $temp_dir") or die;

#Run IdentifyLoh on the 'apipe-test-clinseq-wer' model
my $clinseq_build =
Genome::Model::Build->get(id => '35af836fbcd243c59c44825af7e3983b');
ok($clinseq_build, "Found clinseq build.");
my $run_iloh = Genome::Model::ClinSeq::Command::IdentifyLoh->create(
    outdir => $temp_dir,
    clinseq_build => $clinseq_build,
    bamrc_version => 0.6,
    test => 1,
);
$run_iloh->queue_status_messages(1);
$run_iloh->execute();

#Dump the output to a log file
my @output1 = $run_iloh->status_messages();
my $log_file = $temp_dir . "/IdentifyLoh.log.txt";
my $log = IO::File->new(">$log_file");
$log->print(join("\n", @output1));
$log->close();
ok(-e $log_file, "Wrote message file from identify-loh to a log
    file: $log_file");

#Check for diffs
my @diff = `diff -r -x '*.log.txt' -x '*png' -x '*R' -x '*cbs*' -x '*seg' -x '*.err' -x '*.out' $expected_output_dir $temp_dir`;
ok(@diff == 0, "Found only expected number of differences between expected
    results and test results")
    or do {
    diag("expected: $expected_output_dir\nactual: $temp_dir\n");
    diag("differences are:");
    diag(@diff);
    my $diff_line_count = scalar(@diff);
    Genome::Sys->shellcmd(cmd => "rm -fr /tmp/last-run-identifyloh/");
    Genome::Sys->shellcmd(cmd => "mv $temp_dir /tmp/last-run-identifyloh");
    die print "\n\nFound $diff_line_count differing lines\n\n";
};
done_testing();
