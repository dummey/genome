#!/usr/bin/env genome-perl

use strict;
use warnings;

use above "Genome";

use Test::More;

use_ok('Genome::Model::Tools::MetagenomicClassifier::Rdp::Version2x10') or die;

my $seq = {
    id => 'S000002017 Pirellula staleyi',
    seq => 'AATGAACGTTGGCGGCATGGATTAGGCATGCAAGTCGTGCGCGATATGTAGCAATACATGGAGAGCGGCGAAAGGGAGAGTAATACGTAGGAACCTACCTTCGGGTCTGGGATAGCGGCGGGAAACTGCCGGTAATACCAGATGATGTTTCCGAACCAAAGGTGTGATTCCGCCTGAAGAGGGGCCTACGTCGTATTAGCTAGTTGGTAGGGTAATGGCCTACCAAGnCAAAGATGCGTATGGGGTGTGAGAGCATGCCCCCACTCACTGGGACTGAGACACTGCCCAGACACCTACGGGTGGCTGCAGTCGAGAATCTTCGGCAATGGGCGAAAGCCTGACCGAGCGATGCCGCGTGCGGGATGAAGGCCTTCGGGTTGTAAACCGCTGTCGTAGGGGATGAAGTGCTAGGGGGTTCTCCCTCTAGTTTGACTGAACCTAGGAGGAAGGnCCGnCTAATCTCGTGCCAGCAnCCGCGGTAATACGAGAGGCCCAnACGTTATTCGGATTTACTGGGCTTAAAGAGTTCGTAGGCGGTCTTGTAAGTGGGGTGTGAAATCCCTCGGCTCAACCGAGGAACTGCGCTCCAnACTACAAGACTTGAGGGGGATAGAGGTAAGCGGAACTGATGGTGGAGCGGTGAAATGCGTTGATATCATCAGGAACACCGGAGGCGAAGGCGGCTTACTGGGTCCTTTCTGACGCTGAGGAACGAAAGCTAGGGGAGCAnACGGGATTAGATACCCCGGTAGTCCTAnCCGTAAACGATGAGCACTGGACCGGAGCTCTGCACAGGGTTTCGGTCGTAGCGAAAGTGTTAAGTGCTCCGCCTGGGGAGTATGGTCGCAAGGCTGAAACTCAAAGGAATTGACGGGGGCTCACACAAGCGGTGGAGGATGTGGCTTAATTCGAGGCTACGCGAAGAACCTTATCCTAGTCTTGACATGCTTAGGAATCTTCCTGAAAGGGAGGAGTGCTCGCAAGAGAGCCTnTGCACAGGTGCTGCATGGCTGTCGTCAGCTCGTGTCGTGAGATGTCGGGTTAAGTCCCTTAACGAGCGAAACCCTnGTCCTTAGTTACCAGCGCGTCATGGCGGGGACTCTAAGGAGACTGCCGGTGTTAAACCGGAGGAAGGTGGGGATGACGTCAAGTCCTCATGGCCTTTATGATTAGGGCTGCACACGTCCTACAATnGTGCACACAAAGCGACGCAAnCTCGTGAGAGCCAGCTAAGTTCGGATTGCAGGCTGCAACTCGCCTGCATGAAGCTGGAATCGCTAGTAATCGCGGGTCAGCATACCGCGGTGAATGTGTTCCTGAGCCTTGTACACACCGCCCGTCAAGCCACGAAAGTGGGGGGGACCCAACAGCGCTGCCGTAACCGCAAGGAACAAGGCGCCTAAGGTCAACTCCGTGATTGGGACTAAGTCGTAACAAGGTAGCCGTAGGGGAACCTGCGGCTGGATCACCTCCTT',
};

my $classifier = Genome::Model::Tools::MetagenomicClassifier::Rdp::Version2x10->create(training_set => 10);#(4,6,broad)
ok($classifier, 'Created rdp classifier');

my $classification = $classifier->classify($seq);
ok($classification, 'got classification');

my $i = 0;
my @taxa = (qw/ Root Bacteria Planctomycetes Planctomycetia Planctomycetales Planctomycetaceae Pirellula /);
for my $rank (qw/ root domain phylum class order family genus /) {
    is($classification->{$rank}->{id}, $taxa[$i], "$rank: $taxa[$i]");
    is($classification->{$rank}->{confidence}, '1.0', 'confidence: 1.0');
    $i++;
}
is($classification->{complemented}, 0, 'not complemented');

# classify fails
eval{ $classifier->classify(); };
like($@, qr(No sequence given to classify), 'fail to classify w/ undef sequence');
eval{ $classifier->classify({seq => 'A'}); };
like($@, qr(Seq does not have an id:), 'fail to classify w/o sequence id');
#ok(!$classifier->classify({ id => 'Seq w/o 49 n free words', seq => 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAANAAAAAAAAAAAAAAAAA' }), 'fail to classify sequence w/o 49 n free words');

done_testing();
