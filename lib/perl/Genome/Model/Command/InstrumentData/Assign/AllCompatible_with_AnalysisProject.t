#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_DBI_NO_COMMIT} = 1;
};

use above 'Genome';

use Genome::Test::Factory::AnalysisProject;
use Genome::Test::Factory::InstrumentData::Solexa;
use Genome::Test::Factory::Model::ReferenceAlignment;
use Test::More;

use_ok('Genome::Model::Command::InstrumentData::Assign::AllCompatible') or die;

my $analysis_project = Genome::Test::Factory::AnalysisProject->setup_object(
    config_hash => {
        rules => {
            'sequencing_platform' => 'solexa',
            'is_capture' => 0,
        },
        models => {
            'Genome::Model::ReferenceAlignment' => {
                instrument_data_properties => {
                    subject => 'sample',
                },
            },
        }
    },
);
my ($config_item) = $analysis_project->config_items;

my %solexa_params = (read_length => 10, clusters => 5);

my @good_instrument_data = map Genome::Test::Factory::InstrumentData::Solexa->setup_object(%solexa_params), 1..4;
my @bad_instrument_data = map Genome::Test::Factory::InstrumentData::Solexa->setup_object(%solexa_params), 1..3;
my @other_bad_instrument_data = map Genome::Test::Factory::InstrumentData::Solexa->setup_object(
    %solexa_params,
    target_region_set_name => 'test target set for allcompatible-with-analysisproject',
), 1..2;
my $model = Genome::Test::Factory::Model::ReferenceAlignment->setup_object();

#make sure all share a sample so they are compatible
my $library = $good_instrument_data[0]->library;
map { $_->library($library) } @good_instrument_data, @bad_instrument_data;
$model->subject($library->sample);

$model->add_analysis_project_bridge(analysis_project => $analysis_project, config_profile_item => $config_item);
map $_->add_analysis_project_bridge(analysis_project => $analysis_project), @good_instrument_data, @other_bad_instrument_data;

my $assign = Genome::Model::Command::InstrumentData::Assign::AllCompatible->create(
    model => $model,
);
ok($assign, 'created assign command for model in an analysis project');
ok($assign->execute, 'executed assign command');

my @model_instrument_data = $model->instrument_data;
is_deeply([sort @model_instrument_data], [sort @good_instrument_data], 'command assigned correct set of instrument data');

done_testing();
