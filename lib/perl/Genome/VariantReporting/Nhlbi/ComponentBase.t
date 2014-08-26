#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::Exception;
use Test::More;
use Genome::File::Vcf::Entry;

my $pkg = 'Genome::VariantReporting::Nhlbi::ComponentBase';

my $base = $pkg->create();

my $entry = create_entry();
throws_ok(sub {$base->get_maf_for_entry($entry, "Bad")}, qr(Bad population code), "Bad population code throws an error");
throws_ok(sub {$base->get_maf_for_entry($entry)}, qr(Bad population code), "Missing population code throws an error");
ok(!defined $base->get_maf_for_entry($entry, "All"), "Entry with no maf returns undef");

$entry = create_entry("1");
throws_ok(sub {$base->get_maf_for_entry($entry, "All")}, qr(MAF in unexpected format:), "MAF with wrong format throws exception");

$entry = create_entry("0.001,0.3,0.00012");
is($base->get_maf_for_entry($entry, "All"), 0.00012, "Correctly got maf for All");

done_testing;

sub create_vcf_header {
    my $header_txt = <<EOS;
##fileformat=VCFv4.1
##INFO=<ID=MAF,Number=.,Type=Float,Description="MAF">
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO
EOS
    my @lines = split("\n", $header_txt);
    my $header = Genome::File::Vcf::Header->create(lines => \@lines);
    return $header
}

sub create_entry {
    my $maf = shift;
    my @fields = (
        '1',            # CHROM
        10,             # POS
        '.',            # ID
        'A',            # REF
        'C,G',          # ALT
        '10.3',         # QUAL
        'PASS',         # FILTER
    );
    if (defined $maf) {
        push @fields, "MAF=$maf";
    }
    else {
        push @fields, ".";
    }

    my $entry_txt = join("\t", @fields);
    my $entry = Genome::File::Vcf::Entry->new(create_vcf_header(), $entry_txt);
    return $entry;
}
