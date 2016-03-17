#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use Test::More;

use above 'Genome';
use Genome::Test::Factory::SoftwareResult::User;

Genome::Config::set_env('workflow_builder_backend', 'inline');

if ($] < 5.010) {
    plan skip_all => "this test is only runnable on perl 5.10+"
} elsif (`uname -a` !~ /64/) {
    plan skip_all => "this test requires 64-bit architecture"
} else {
    plan tests => 12;
}

use_ok('Genome::InstrumentData::AlignmentResult::Merged::CoverageStats');

my $data_dir = Genome::Config::get('test_inputs') . '/Genome-InstrumentData-AlignmentResult-Merged-CoverageStats';

my ($merged_result, $feature_list) = &setup_data();

my $result_users = Genome::Test::Factory::SoftwareResult::User->setup_user_hash(
    reference_sequence_build => $merged_result->reference_build,
);

my %coverage_stats_params = (
    alignment_result_id => $merged_result->id,
    region_of_interest_set_id => $feature_list->id,

    minimum_depths => '1,10,20',
    wingspan_values => '0,200',
    minimum_base_quality => 20,
    minimum_mapping_quality => 1,
    use_short_roi_names => 1,
    merge_contiguous_regions => 1,

    users => $result_users,
);

my $coverage_result = Genome::InstrumentData::AlignmentResult::Merged::CoverageStats->get_or_create(%coverage_stats_params);
isa_ok($coverage_result, 'Genome::InstrumentData::AlignmentResult::Merged::CoverageStats', 'sucessful run');
is($coverage_result->get_target_total_bp, 130000, 'target_total_bp');

my $alignment_summary = $coverage_result->alignment_summary_hash_ref;
ok($alignment_summary, 'produced alignment summary');
my $coverage_stats_summary = $coverage_result->coverage_stats_summary_hash_ref;
ok($coverage_stats_summary, 'produced coverage stats summary');

my $coverage_result2 = Genome::InstrumentData::AlignmentResult::Merged::CoverageStats->get_with_lock(%coverage_stats_params);
is($coverage_result2, $coverage_result, 'got same result for get() after get_or_create()');

$coverage_stats_params{wingspan_values} = '0,100';
$coverage_stats_params{use_short_roi_names} = 0;
my $coverage_result3 = Genome::InstrumentData::AlignmentResult::Merged::CoverageStats->get_with_lock(%coverage_stats_params);
ok(!$coverage_result3, 'request with different (yet unrun) parameters returns no result');

my $coverage_result4 = Genome::InstrumentData::AlignmentResult::Merged::CoverageStats->get_or_create(%coverage_stats_params);
isa_ok($coverage_result4, 'Genome::InstrumentData::AlignmentResult::Merged::CoverageStats', 'sucessful run');
isnt($coverage_result4, $coverage_result, 'produced different result');

my $coverage_stats = $coverage_result4->coverage_stats_hash_ref;
ok($coverage_stats, 'produced stats when long names used');

sub setup_data {

    my $refseq = Genome::Model::Build::ReferenceSequence->get_by_name('NCBI-human-build36');

    my $merged_result = Genome::InstrumentData::AlignmentResult::Merged->__define__(
        id => '-10000', #hardcoded so calculated 'bam_file' returns expected result
        output_dir => ($data_dir . '/merged_result'),
        reference_build => $refseq,
    );
    $merged_result->lookup_hash($merged_result->calculate_lookup_hash());
    isa_ok($merged_result, 'Genome::InstrumentData::AlignmentResult::Merged', 'created merged result');

    my $fl_cmd = Genome::FeatureList::Command::Create->create(
        name => 'test for coverage-stats',
        format => 'true-BED',
        file_path => ($data_dir .  '/feature_list/roi.bed'),
        reference => $refseq,
        content_type => 'roi',
        description => 'test data',
    );
    my $feature_list = $fl_cmd->execute();
    isa_ok($feature_list, 'Genome::FeatureList', 'created feature list');

    return ($merged_result, $feature_list);
}
