#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::Model::Command::Define::MetagenomicCompositionShotgun') or die;

my $pp = Genome::ProcessingProfile::MetagenomicCompositionShotgun->get(2378727);# human microbiome metagenomic alignment with samtools merge
ok($pp, 'pp');
my $subject = Genome::Sample->create(name => '__TEST_SAMPLE__');
ok($subject, 'subject');
my $project = Genome::Project->create(name => '__TEST_PROJECT__');
ok($project, 'create project');

my $contamination_screen_reference = 111751613;
my $metagenomic_reference = 111742950;

my $cmd = Genome::Model::Command::Define::MetagenomicCompositionShotgun->create(
    name => '__TEST_MCS_MODEL__',
    processing_profile => $pp,
    subject => $subject,
    projects => [ $project ],
    params => [ 
        'contamination_screen_reference=model_name=apipe-testdata-refseq-minicontam,status=Succeeded', # 111751613
        'metagenomic_references='.$metagenomic_reference,
        'metagenomic_references='.$contamination_screen_reference, # verify it can do 2 
        'auto_assign_inst_data=0',
        'auto_build_alignments=1',
    ],
);
ok($cmd, 'create');
$cmd->dump_status_messages(1);
ok($cmd->execute, 'execute');

my $model = $cmd->_model;
ok($model, 'created model');
ok(!$model->auto_assign_inst_data, 'auto_assign_inst_data is off');
ok($model->auto_build_alignments, 'auto_build_alignments is on');
is($model->contamination_screen_reference->id, $contamination_screen_reference, 'contamination_screen_reference set');
is_deeply([sort {$a <=> $b } map { $_->id } $model->metagenomic_references], [$metagenomic_reference, $contamination_screen_reference], 'metagenomic_references set');
my @projects = $model->projects;
is_deeply(\@projects, [$project], 'added a project');
ok($model->delete, 'delete model');

# fail
my $fail_cmd = Genome::Model::Command::Define::MetagenomicCompositionShotgun->create(
    name => '__TEST_MCS_MODEL__',
    processing_profile => $pp,
    subject => $subject,
    params => [ 
        'no_exist_property=1',
    ],
);
ok($fail_cmd, 'create');
$fail_cmd->dump_status_messages(1);
ok(!eval{ $fail_cmd->execute; }, 'failed to execute w/ property that does not exist');

$fail_cmd = Genome::Model::Command::Define::MetagenomicCompositionShotgun->create(
    name => '__TEST_MCS_MODEL__',
    processing_profile => $pp,
    subject => $subject,
    params => [ 
     'last_complete_build_directory=1'
    ],
);
ok($fail_cmd, 'create');
$fail_cmd->dump_status_messages(1);
ok(!eval{ $fail_cmd->execute; }, 'failed to execute w/ property that is calculated');

done_testing();
