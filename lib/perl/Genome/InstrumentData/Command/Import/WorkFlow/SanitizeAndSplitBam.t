#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_COMMAND_DUMP_DEBUG_MESSAGES} =1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} =1;
}

use strict;
use warnings;

use above 'Genome';

require Genome::Utility::Test;
require File::Compare;
require File::Spec;
require File::Temp;
require List::MoreUtils;
require Sub::Install;
use Test::Exception;
use Test::More tests => 26;

my $class = 'Genome::InstrumentData::Command::Import::WorkFlow::SanitizeAndSplitBam';
use_ok($class) or die;
my $test_dir = Genome::Utility::Test->data_dir_ok('Genome::InstrumentData::Command::Import', 'v3') or die;
Genome::InstrumentData::Command::Import::WorkFlow::Helpers->overload_uuid_generator_for_class($class);
my $library = Genome::Library->__define__(
    name => 'TEST-SAMPLE-extlibs',
    sample => Genome::Sample->__define__(name => 'TEST-SAMPLE'),
);
ok($library, 'create library');

subtest 'separate reads' => sub{
    plan tests => 7;

    my $read = [ 'read', 0 ];
    my $read1 = ['read1', 8 ];
    my $secondary = ['secondary', 320 ];
    my $read2 = ['read2', 128 ];
    my $supplementary = ['supplementary', 2048 ];

    my @r = Genome::InstrumentData::Command::Import::WorkFlow::SanitizeAndSplitBam::_separate_reads($read);
    is_deeply(\@r, [$read, undef], 'separate single read w/o flag info');

    @r = Genome::InstrumentData::Command::Import::WorkFlow::SanitizeAndSplitBam::_separate_reads($read1, $read1);
    is_deeply(\@r, [$read1, undef], 'separate reads when given 2 read1s');

    @r = Genome::InstrumentData::Command::Import::WorkFlow::SanitizeAndSplitBam::_separate_reads($read1, $secondary);
    is_deeply(\@r, [$read1, undef], 'separate reads when given read1 and secondary');

    @r = Genome::InstrumentData::Command::Import::WorkFlow::SanitizeAndSplitBam::_separate_reads($secondary);
    is_deeply(\@r, [$secondary, undef], 'separate secondary read');

    @r = Genome::InstrumentData::Command::Import::WorkFlow::SanitizeAndSplitBam::_separate_reads($supplementary);
    is_deeply(\@r, [undef, undef], 'separate supplementary read');

    @r = Genome::InstrumentData::Command::Import::WorkFlow::SanitizeAndSplitBam::_separate_reads($secondary, $supplementary, $read1, $read2);
    is_deeply(\@r, [$secondary, $read2], 'separate secondary, supplementary, read1, and read2');

    @r = Genome::InstrumentData::Command::Import::WorkFlow::SanitizeAndSplitBam::_separate_reads($read2);
    is_deeply(\@r, [undef, $read2], 'separate read2');

};

subtest "determine type" => sub{
    plan tests => 4;

    my $type = Genome::InstrumentData::Command::Import::WorkFlow::SanitizeAndSplitBam::_determine_type(1, 1);
    is($type, 'paired', 'given 2 reads, type is paired');

    $type = Genome::InstrumentData::Command::Import::WorkFlow::SanitizeAndSplitBam::_determine_type(1, undef);
    is($type, 'singleton', 'given read1, type is singleton');

    $type = Genome::InstrumentData::Command::Import::WorkFlow::SanitizeAndSplitBam::_determine_type(undef, 1);
    is($type, 'singleton', 'given read2, type is singleton');

    throws_ok(
        sub{ Genome::InstrumentData::Command::Import::WorkFlow::SanitizeAndSplitBam::_determine_type(undef, undef); },
        qr/No reads given to determine type\!/,
        'determine reads fails w/o reads',
    );

};

subtest 'correct_sequence_and_qualities' => sub{
    plan tests => 2;

    my @read_tokens;
    my $seq = 'AATTTCCCGG';
    my $revcomp_seq = 'CCGGGAAATT';
    my $qual = '0123456789';
    my $revcomp_qual = reverse $qual;

    @read_tokens = ( undef, 0, undef, undef, undef, undef, undef, undef, undef, $seq, $qual );
    Genome::InstrumentData::Command::Import::WorkFlow::SanitizeAndSplitBam::_correct_sequence_and_qualities(\@read_tokens);
    is_deeply(\@read_tokens, [ undef, 0, undef, undef, undef, undef, undef, undef, undef, $seq, $qual ], 'non complemented read');

    splice(@read_tokens, 1, 1, 16);
    Genome::InstrumentData::Command::Import::WorkFlow::SanitizeAndSplitBam::_correct_sequence_and_qualities(\@read_tokens);
    is_deeply(\@read_tokens, [ undef, 16, undef, undef, undef, undef, undef, undef, undef, $revcomp_seq, $revcomp_qual ], 'complemented read');

};

my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
my $multi_rg_base_name = 'input.rg-multi.bam';
my $multi_rg_bam_path = File::Spec->join($tmp_dir, $multi_rg_base_name);
Genome::Sys->create_symlink(File::Spec->join($test_dir, $multi_rg_base_name), $multi_rg_bam_path);
ok(-s $multi_rg_bam_path, 'linked two read groups bam');
my $cmd = $class->execute(
    working_directory => $tmp_dir,
    bam_path => $multi_rg_bam_path,
    library => $library,
);
ok($cmd->result, 'execute');

my @output_bam_paths = $cmd->output_bam_paths;
my @bam_basenames = (qw/ 2883581797.paired 2883581797.read1 2883581797.read2 2883581798.paired 2883581798.read1 2883581798.read2 /);
is(@output_bam_paths, @bam_basenames, '6 read group bam paths');
for my $basename ( @bam_basenames ) {
    my $output_bam_path = File::Spec::->join($tmp_dir, 'input.rg-multi.'.$basename.'.bam');
    ok((List::MoreUtils::any { $_ eq $output_bam_path } @output_bam_paths), 'expected bam in output bams');
    ok(-s $output_bam_path, 'expected bam path exists');
    my $expected_bam_path = File::Spec->join($test_dir, 'split-by-rg.'.$basename.'.bam');
    is(File::Compare::compare($output_bam_path, $expected_bam_path), 0, "expected $basename bam path matches");
}
ok(!glob($multi_rg_bam_path.'*'), 'removed bam path and auxiliary files after spliting');

#diag($tmp_dir); <STDIN>;
done_testing();
