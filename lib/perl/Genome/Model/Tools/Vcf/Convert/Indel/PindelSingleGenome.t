#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use File::Temp;

plan tests => 5;

Genome::Config::set_env('workflow_builder_backend', 'inline');

my $refseq_tmp_dir = File::Temp::tempdir(CLEANUP => 1);
no warnings;
use Genome::Model::Build::ReferenceSequence;
*Genome::Model::Build::ReferenceSequence::local_cache_basedir = sub { return $refseq_tmp_dir; };
*Genome::Model::Build::ReferenceSequence::copy_file = sub { 
    my ($build, $file, $dest) = @_;
    symlink($file, $dest) || die;
    return 1; 
};
use warnings;

use_ok('Genome::Model::Tools::Vcf::Convert::Indel::PindelSingleGenome');

my $test_dir = Genome::Config::get('test_inputs') . "/Genome-Model-Tools-Vcf-Convert-Indel-PindelSingleGenome";

my $expected_base = "expected.v4";
my $input_base = "test_input";
my $expected_dir = "$test_dir/$expected_base";
my $input_dir = "$test_dir/$input_base";
my $expected_file = "$expected_dir/output.vcf.gz";

my $output_file = Genome::Sys->create_temp_file_path("test.vcf.gz");
my $input_file = "$input_dir/indels.hq";
$DB::single=1;
my $command = Genome::Model::Tools::Vcf::Convert::Indel::PindelSingleGenome->create( 
    input_file => $input_file,
    output_file => $output_file,
    aligned_reads_sample => "tumor",
    reference_sequence_build_id => 101947881
);

ok($command, 'Command created');
my $rv = $command->execute;
ok($rv, 'Command completed successfully');
ok(-s $output_file, "output file created");

#The files will have a timestamp that will differ. Ignore this but check the rest.
my $expected = `zcat $expected_file | grep -v fileDate`;
my $output = `zcat $output_file | grep -v fileDate`;

my $diff = Genome::Sys->diff_text_vs_text($output, $expected);
ok(!$diff, 'output matched expected result')
    or diag("diff results:\n" . $diff);
