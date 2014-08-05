#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above "Genome";

use Test::More;

my $cmd_class = 'Genome::Model::Tools::Joinx::VcfMerge';
use_ok($cmd_class) or die;

my $test_data_directory = __FILE__ . '.d';
my @non_empty_input_files = (
    join('/', $test_data_directory, 'input.clean.vcf'),
    join('/', $test_data_directory, 'input2.clean.vcf'),
);
my @non_empty_labeled_input_files = (
    join('/', $test_data_directory, 'input.clean.vcf=inputone'),
    join('/', $test_data_directory, 'input2.clean.vcf=inputtwo'),
);
my @empty_input_files = (
    join('/', $test_data_directory, 'test_empty1.clean.vcf'),
    join('/', $test_data_directory, 'test_empty2.clean.vcf'),
);
my @missing_input_files = (
    join('/', $test_data_directory, 'foo'),
    join('/', $test_data_directory, 'bar'),
);


# test _resolve_inputs
my $cmd = $cmd_class->create(
    input_files => [@non_empty_input_files,
                    @empty_input_files,
                    @missing_input_files],
);
my @inputs = $cmd->_resolve_inputs();
is_deeply(\@inputs, \@non_empty_input_files, 'Resolved inputs properly');


#test _resolve_output
$cmd = $cmd_class->create(
    input_files => [@non_empty_input_files], # not optional
    output_file => undef,
);
my $output = $cmd->_resolve_output();
is($output, '-', 'Undefined output_file resolves properly');

$cmd = $cmd_class->create(
    input_files => [@non_empty_input_files], # not optional
    output_file => $missing_input_files[0],
);
$output = $cmd->_resolve_output();
is($output, $missing_input_files[0], 'Defined output_file resolves properly');


# test _resolve_flags
$cmd = $cmd_class->create(
    input_files => [@non_empty_input_files], # not optional
);
$output = $cmd->_resolve_flags();
is($output, "", 'Flag resolution 1');

$cmd = $cmd_class->create(
    input_files => [@non_empty_input_files], # not optional
    clear_filters => 1,
    sample_priority => 'order',
    merge_samples => 1,
    ratio_filter => 10,
);
$output = $cmd->_resolve_flags();
is($output, ' -c -P o -s -R "10"', 'Flag resolution 2');


# test _generate_joinx_command
my $joinx_bin_path = 'JOINX';
my $flags = 'FLAGS';
my $inputs = \@non_empty_input_files;
my $output_file = $missing_input_files[0];
my $labeled_inputs = [];
my $labeled_inputs_hash = {};

$cmd = $cmd_class->create(
    input_files => \@non_empty_input_files, # not optional
    output_file => $missing_input_files[0],
);
($output) = $cmd->_generate_joinx_command($joinx_bin_path, $flags,
        $inputs, $labeled_inputs, $labeled_inputs_hash, $output_file);
my $expected = sprintf("JOINX vcf-merge FLAGS %s -o " . __FILE__ . ".d/foo",
        join(' ', @non_empty_input_files));
is($output, $expected, 'Command is generated correctly 1');

$cmd = $cmd_class->create(
    input_files => \@non_empty_input_files, # not optional
    output_file => $missing_input_files[0],
    use_bgzip => 1,
    use_version => 1.7, # 1.7 is the last version that will contain zcat
);
($output) = $cmd->_generate_joinx_command($joinx_bin_path, $flags,
        $inputs, $labeled_inputs, $labeled_inputs_hash, $output_file);
$expected = sprintf("JOINX vcf-merge FLAGS %s | bgzip -c > " . __FILE__ . ".d/foo",
        join(' ', map { "<(zcat $_)" } @non_empty_input_files));
is($output, $expected, 'Command is generated correctly 2');

$cmd = $cmd_class->create(
    input_files => \@non_empty_input_files, # not optional
    output_file => $missing_input_files[0],
    use_bgzip => 1,
    error_log => 'ERROR',
    use_version => 1.7, # 1.7 is the last version that will contain zcat
);
($output) = $cmd->_generate_joinx_command($joinx_bin_path, $flags,
        $inputs, $labeled_inputs, $labeled_inputs_hash, $output_file);
$expected = sprintf("JOINX vcf-merge FLAGS %s 2> ERROR | bgzip -c > " . __FILE__ . ".d/foo",
        join(' ', map { "<(zcat $_)" } @non_empty_input_files));
is($output, $expected, 'Command is generated correctly 3');

$cmd = $cmd_class->create(
    input_files => \@non_empty_input_files, # not optional
    output_file => $missing_input_files[0],
    error_log => 'ERROR',
);
($output) = $cmd->_generate_joinx_command($joinx_bin_path, $flags,
        $inputs, $labeled_inputs, $labeled_inputs_hash, $output_file);
$expected = sprintf("JOINX vcf-merge FLAGS %s -o " . __FILE__ . ".d/foo 2> ERROR",
        join(' ', @non_empty_input_files));
is($output, $expected, 'Command is generated correctly 4');

subtest 'test joinx 1.9 does not use zcat' => sub {
    $cmd = $cmd_class->create(
        input_files => \@non_empty_input_files, # not optional
        output_file => $missing_input_files[0],
        error_log => 'ERROR',
        use_bgzip => 1,
        use_version => 1.9,
    );
    ($output) = $cmd->_generate_joinx_command($joinx_bin_path, $flags,
        $inputs, $labeled_inputs, $labeled_inputs_hash, $output_file);
    $expected = sprintf("JOINX vcf-merge FLAGS %s 2> ERROR | bgzip -c > " . __FILE__ . ".d/foo",
        join(' ', @non_empty_input_files));
    is($output, $expected, 'Command is generated correctly 5');
};

# INTEGRATION TEST
my $temp_dir = Genome::Sys->create_temp_directory();
my $output_vcf = join('/', $temp_dir, 'output.vcf');
$cmd = $cmd_class->create(
    input_files => \@non_empty_input_files,
    output_file => $output_vcf,
    merge_samples => 1,
);
ok(!-e $output_vcf, 'Output file does not exist yet');
$output = $cmd->execute();
ok($output, 'Executed successfully');
ok(-e $output_vcf, 'Output file exists');

# LABELED OUTPUT INTEGRATION TEST
$temp_dir = Genome::Sys->create_temp_directory();
$output_vcf = join('/', $temp_dir, 'output.vcf');
$cmd = $cmd_class->create(
    labeled_input_files => \@non_empty_labeled_input_files,
    output_file => $output_vcf,
    merge_samples => 1,
);
ok(!-e $output_vcf, 'Output file does not exist yet');
$output = $cmd->execute();
ok($output, 'Executed successfully');
ok(-e $output_vcf, 'Output file exists');

# BGZIP INTEGRATION TEST
my @gzip_files;
for my $i (0..$#non_empty_input_files) {
    my $gzip_file = join('/', $temp_dir, "$i.vcf.gz");
    system('gzip -1c ' . $non_empty_input_files[$i] . " > $gzip_file");
    push @gzip_files, $gzip_file;
}

$output_vcf = $output_vcf . '.gz';
$cmd = $cmd_class->create(
    input_files => \@gzip_files,
    output_file => $output_vcf,
    use_bgzip => 1,
    merge_samples => 1,
);
ok(!-e $output_vcf, 'bgzipped output file does not exist yet');
$output = $cmd->execute();
ok($output, 'Executed successfully');
ok(-e $output_vcf, 'bgzipped output file exists');

done_testing();


1;
