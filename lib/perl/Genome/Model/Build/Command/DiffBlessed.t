#!/usr/bin/env genome-perl

use strict;
use warnings;

use Test::More;
use File::Temp;
use above 'Genome';

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use_ok("Genome::Model::Build::Command::DiffBlessed") or die;

#only going to test our methods here as testing the class is above my current skill level

my $model_name = "super-awesome-fake-model";
my $build_id = -7777777;
my $perl_version = '5.10';
#create test YAML file
    my $yaml = <<YAML;
---
$model_name: $build_id\n
YAML

{
    local *Genome::Model::Build::get;
    *Genome::Model::Build::get = sub { return $_[2]; };

    like(Genome::Model::Build::Command::DiffBlessed->db_file, qr(Genome/Model/Build/Command/DiffBlessed.pm.YAML$),
        "yaml file is found correctly");
    ok(-s Genome::Model::Build::Command::DiffBlessed->db_file, "Yaml file exists");
    my $fh = File::Temp->new();
    ok($fh, 'Created temp file') or die;
    my $retval = print $fh $yaml;
    ok($retval, "wrote test YAML file") or die;
    $fh->close;

    Sub::Install::reinstall_sub({
        into => 'Genome::Interfaces::Comparable::Command::DiffBlessed',
        as => 'db_file',
        code => sub {return $fh->filename},
    });
    is(Genome::Model::Build::Command::DiffBlessed->retrieve_blessed_build($model_name, $perl_version, $fh->filename ), $build_id, "blessed build returned as expected");
}
done_testing();


