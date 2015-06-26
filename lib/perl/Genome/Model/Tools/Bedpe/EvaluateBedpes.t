#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Genome::Utility::Test qw(compare_ok);

my $pkg = "Genome::Model::Tools::Bedpe::EvaluateBedpes";
my $version = "v2";
use_ok($pkg);

my $data_dir = Genome::Utility::Test->data_dir_ok($pkg, $version);

my $config_file = Genome::Sys->create_temp_file_path;
my @config = (
    join("\t", qw(caller_name gold_name data_name bedpe gold_bedpe slop)),
    "\n",
    join("\t", "Caller1", "Gold1", "Data1", File::Spec->join($data_dir, "a.bedpe"), File::Spec->join($data_dir, "gold.bedpe"), 0),
    "\n",
    join("\t", "Caller1", "Gold1", "Data1", File::Spec->join($data_dir, "a.bedpe"), File::Spec->join($data_dir, "gold2.bedpe"), 1000),
);
Genome::Sys->write_file($config_file, @config);
my $json = Genome::Sys->create_temp_file_path;

my $cmd = $pkg->create(
    config_file => $config_file,
    output_json => $json,
    bedtools_version => '2.17.0',
);
ok($cmd->execute, "Command executed ok");

my $expected_json = File::Spec->join($data_dir, "expected.json");
compare_ok($json, $expected_json);
done_testing;
