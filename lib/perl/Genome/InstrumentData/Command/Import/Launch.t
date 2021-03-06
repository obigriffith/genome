#!/usr/bin/env genome-perl

BEGIN {
    $ENV{NO_LSF} = 1;
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
    $ENV{UR_COMMAND_DUMP_DEBUG_MESSAGES} = 1;
}

use strict;
use warnings;

use above "Genome";

require Cwd;
use Data::Dumper;
require Digest::MD5;
require File::Spec;
require Genome::Utility::Test;
use Test::More;
use Test::Exception;

my $class = 'Genome::InstrumentData::Command::Import::Launch';
use_ok($class) or die;

my $cwd = Cwd::getcwd();
my $data_dir = Genome::Utility::Test->data_dir_ok('Genome::InstrumentData::Command::Import', File::Spec->join('launch', 'v1'));
my $import_file = File::Spec->join($data_dir, 'info.tsv');
chdir $data_dir;
my $analysis_project = Genome::Config::AnalysisProject->create(name => '__TEST_AP__');
ok($analysis_project, 'create analysis project');
my $job_group_name = '/somebody/import';
my %params = (
    analysis_project => $analysis_project,
    file => $import_file,
    job_group_name => $job_group_name,
);

# fail - active processes
my $existing_process = Genome::InstrumentData::Command::Import::Process->create(
    import_file => $import_file,
);
ok($existing_process, 'create existing process');
for my $status (qw/ New Scheduled Running /) {
    $existing_process->status($status);
    is($existing_process->status, $status, "existing_process status is $status");
    throws_ok(
        sub{ $class->execute(%params); },
        qr/Cannot start another import process until the previous one has completed\!/,
        'failed to execute w/ active process',
    );
}
$existing_process->status('Crashed');

# fail - no library
throws_ok(
    sub{ $class->execute(%params); },
    qr/No library for name: TeSt\-0000\-00\-extlibs/,
    'failed to execute w/o libraries',
);

# define libraries
my $base_sample_name = 'TeSt-0000-0';
my @libraries;
for (0..1) { 
    push @libraries, Genome::Library->__define__(
        id => -222 + $_,
        name => $base_sample_name.$_.'-extlibs',
        sample => Genome::Sample->__define__(
            id => -111 + $_,
            name => $base_sample_name.$_,
            nomenclature => 'TeSt',
        ),
    );
}
is(@libraries, 2, 'define 2 libraries');

# success
my $launch = $class->execute(%params);
ok($launch->result, 'launch!');
is($launch->gtmp, 1, 'gtmp');

my @instdata = Genome::InstrumentData::Imported->get(library_id => [map {$_->id} @libraries]);
is(@instdata, 2, 'create 2 instrument data');
my @instdata_process_attrs = map { $_->attributes(attribute_label => 'process_id') } @instdata;
is(@instdata_process_attrs, 2, 'added process_id attrs to instdata');

# fail - source file does not exist
throws_ok(
    sub{
        Genome::InstrumentData::Command::Import::Launch->execute(
            analysis_project => $analysis_project,
            file => File::Spec->join($data_dir, 'source-file-does-not-exist.tsv'),
            job_group_name => $job_group_name,
        );
    },
    qr/^Source file does not have any size\! bam4\.bam/,
    'execute failed w/ non existing source file',
);

chdir $cwd;
done_testing();
