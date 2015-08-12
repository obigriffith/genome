#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above 'Genome';

use Test::More;

if (Genome::Sys->arch_os ne 'x86_64') {
    plan skip_all => 'requires 64-bit machine';
}
else {
    plan tests => 5;
}

use_ok('Genome::Model::Tools::Gatk::PrintReads');

# Inputs
my $test_data_dir = Genome::Config::get('test_inputs') . '/Genome-Model-Tools-Gatk-PrintReads/v1';
my @input_bams   = ("$test_data_dir/input1.bam", "$test_data_dir/input2.bam");
my $input_grp    = "$test_data_dir/input.grp";
my $input_ref_mt = "$test_data_dir/all_sequences.MT.fa";

# Outputs
my $output_dir = File::Temp::tempdir('GMTGatkPrintReadsXXXXX', CLEANUP => 1, TMPDIR => 1);
my $output_bam = "$output_dir/test.bam";

# Expected
my $expected_bam = "$test_data_dir/expected.bam";

my $gatk_cmd = Genome::Model::Tools::Gatk::PrintReads->create(
        max_memory      => "2",
        version         => 2.4,
        number_of_cpu_threads => 1,
        input_bams      => [@input_bams],
        reference_fasta => $input_ref_mt,
        bqsr            => $input_grp,
        output_bam      => $output_bam,
);

isa_ok($gatk_cmd, 'Genome::Model::Tools::Gatk::PrintReads', "Made the command");
diag(join(' ', $gatk_cmd->gatk_command));
ok($gatk_cmd->execute, "Executed the command");
ok(system("diff $output_bam $expected_bam") == 0, "Output and expected are not different.");
ok(-s $output_bam.'.bai', 'bam index exists');

done_testing();
