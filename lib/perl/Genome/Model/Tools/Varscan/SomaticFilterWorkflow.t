#!/usr/bin/env genome-perl

use strict;
use warnings;

use above "Genome";
use Test::More;
use Genome::Utility::Test qw(compare_ok);

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{NO_LSF} = 1;
};

use_ok('Genome::Model::Tools::Varscan::SomaticFilterWorkflow') or die;
my $expected_output_dir =
  Genome::Utility::Test->data_dir_ok('Genome::Model::Tools::Varscan::SomaticFilterWorkflow','2015-02-06');
ok(-e $expected_output_dir,
    "Found test dir: $expected_output_dir") or die;

my $clinseq_model = Genome::Model->get(name => "apipe-test-clinseq-wer");
ok($clinseq_model, "found clinseq model");
my $tumor_bam =
    $clinseq_model->wgs_model->tumor_model->last_succeeded_build->merged_alignment_result->bam_path;
ok($tumor_bam, "found tumor bam");
my $normal_bam =
    $clinseq_model->wgs_model->normal_model->last_succeeded_build->merged_alignment_result->bam_path;
ok($normal_bam, "found normal bam");
my $ref_fa =
    $clinseq_model->wgs_model->normal_model->last_succeeded_build->reference_sequence_build->full_consensus_path('fa');
ok($ref_fa, "found reference fasta");

my $temp_dir = Genome::Sys->create_temp_directory();
ok($temp_dir, "created temp directory: $temp_dir") or die;

#Run somatic filter.
my $somatic_filter =
Genome::Model::Tools::Varscan::SomaticFilterWorkflow->create(
    outdir => $temp_dir,
    tumor_bam => $tumor_bam,
    normal_bam => $normal_bam,
    prefix => File::Spec->join(
        $expected_output_dir,
        "varscan.snps"),
    reference => $ref_fa,
);
$somatic_filter->queue_status_messages(1);
$somatic_filter->execute();

#Perform a diff between the stored results and those generated by this test
my @diff = `diff -r -x varscan.snps.1.snp -x varscan.snps.2.snp -x *.err -x *.out $expected_output_dir $temp_dir`;
ok(@diff == 0, "Found only expected number of differences between expected results and test results") or do {
    diag("expected: $expected_output_dir\nactual: $temp_dir\n");
    diag("differences are:");
    diag(@diff);
    my $diff_line_count = scalar(@diff);
    print "\n\nFound $diff_line_count differing lines\n\n";
    Genome::Sys->shellcmd(cmd => "rm -fr /tmp/last-run-somaticfilterworkflow/");
    Genome::Sys->shellcmd(cmd => "mv $temp_dir /tmp/last-run-somaticfilterworkflow");
};

done_testing();