#!/usr/bin/env genome-perl
use strict;
use warnings;

$Genome::Sys::IS_TESTING=1;
BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
};

use above 'Genome';
use Data::Dumper;
use File::Path;
use File::Spec;
use File::Temp;
use Test::More;
use POSIX ":sys_wait_h";
use File::Slurp;
use Time::HiRes qw(gettimeofday);
use MIME::Base64;

require_ok('Genome::Sys::Lock');

my $tmp_dir = File::Temp::tempdir('Genome-Utility-FileSystem-writetest-XXXXX', DIR => "$ENV{GENOME_TEST_TEMP}", CLEANUP => 1);

my $bogus_id = '-55555';
$tmp_dir = File::Temp::tempdir(CLEANUP => 1);
my $sub_dir = $tmp_dir .'/sub/dir/test';
ok(! -e $sub_dir,$sub_dir .' does not exist');
ok(Genome::Sys->create_directory($sub_dir),'create directory');
ok(-d $sub_dir,$sub_dir .' is a directory');

test_locking(successful => 1,
    message => 'lock resource_id '. $bogus_id,
    lock_directory => $tmp_dir,
    resource_id => $bogus_id,);

test_locking(successful => 0,
    wait_on_self => 1,
    message => 'failed lock resource_id '. $bogus_id,
    lock_directory => $tmp_dir,
    resource_id => $bogus_id,
    max_try => 1,
    block_sleep => 3,);

ok(Genome::Sys->unlock_resource(
        lock_directory => $tmp_dir,
        resource_id => $bogus_id,
    ), 'unlock resource_id '. $bogus_id);
my $init_lsf_job_id = $ENV{'LSB_JOBID'};
{
    local $ENV{'LSB_JOBID'};
    $ENV{'LSB_JOBID'} = 1;
    test_locking(successful => 1,
        message => 'lock resource with bogus lsf_job_id',
        lock_directory => $tmp_dir,
        resource_id => $bogus_id,);
    test_locking(
        successful=> 1,
        wait_on_self => 1,
        message => 'lock resource with removing invalid lock with bogus lsf_job_id first',
        lock_directory => $tmp_dir,
        resource_id => $bogus_id,
        max_try => 1,
        block_sleep => 3,);
    ok(Genome::Sys->unlock_resource(
            lock_directory => $tmp_dir,
            resource_id => $bogus_id,
        ), 'unlock resource_id '. $bogus_id);
# TODO: add skip test but if we are on a blade, lets see that the locking works correctly
# Above the test is that old bogus locks can get removed when the lsf_job_id no longer exists
# We should test that while an lsf_job_id does exist (ie. our current job) we still hold the lock
    SKIP: {
        skip 'only test the state of the lsf job if we are running on a blade with a job id',
        3 unless ($init_lsf_job_id);
        $ENV{'LSB_JOBID'} = $init_lsf_job_id;
        ok(Genome::Sys->lock_resource(
                lock_directory => $tmp_dir,
                resource_id => $bogus_id,
            ),'lock resource with real lsf_job_id');
        ok(!Genome::Sys->lock_resource(
                lock_directory => $tmp_dir,
                resource_id => $bogus_id,
                max_try => 1,
                block_sleep => 3,
                wait_on_self => 1,
            ),'failed lock resource with real lsf_job_id blocking');
        ok(Genome::Sys->unlock_resource(
                lock_directory => $tmp_dir,
                resource_id => $bogus_id,
            ), 'unlock resource_id '. $bogus_id);
    };
}

# RACE CONDITION
my $base_dir = File::Temp::tempdir("Genome-Utility-FileSystem-RaceCondition-XXXX", DIR=>"$ENV{GENOME_TEST_TEMP}/", CLEANUP=>1);

my $resource = "/tmp/Genome-Utility-Filesystem.test.resource.$$";

if (defined $ENV{'LSB_JOBID'} && $ENV{'LSB_JOBID'} eq "1") {
    delete $ENV{'LSB_JOBID'}; 
}

my @pids;

my $children = 20;

for my $child (1...$children) {
    my $pid;
    if ($pid = UR::Context::Process->fork()) {
        push @pids, $pid;
    } else {
        my $output_offset = $child;
        my $tempdir = $base_dir;
        my $output_file = $tempdir . "/" . $output_offset;

        my $fh = new IO::File(">>$output_file");

        my $lock = Genome::Sys->lock_resource(
            resource_lock => $resource,
            block_sleep   => 1,
            wait_announce_interval => 30,
        );
        unless ($lock) {
            print_event($fh, "LOCK_FAIL", "Failed to get a lock" );
            $fh->close;
            exit(1);
        }

        #sleep for half a second before printing this, to let a prior process catch up with
        #printing its "unlocked" message.  sometimes we get a lock (properly) in between the time
        #someone else has given up the lock, but before it had a chance to report that it did.
        select(undef, undef, undef, 0.50);
        print_event($fh, "LOCK_SUCCESS", "Successfully got a lock" );
        sleep 2;

        unless (Genome::Sys->unlock_resource(resource_lock => $resource)) {
            print_event($fh, "UNLOCK_FAIL", "Failed to release a lock" );
            $fh->close;
            exit(1);
        }
        print_event($fh, "UNLOCK_SUCCESS", "Successfully released my lock" );

        $fh->close;
        exit(0);
    }
}

for my $pid (@pids) {
    my $status = waitpid $pid, 0;
}

my @event_log;

for my $child (1...$children) {
    my $report_log = "$base_dir/$child";
    ok (-e $report_log, "Expected to see a report for $report_log");
    if (!-e $report_log) {
        die "Expected output file did not exist";
    } else {
        my @lines = read_file($report_log);
        for (@lines) {
            my ($time, $event, $pid, $msg) = split /\t/;
            my $report = {etime => $time, event=>$event, pid=>$pid, msg=>$msg};
            push @event_log, $report;
        } 
    }
}

ok(scalar @event_log  == 2*$children, "read in got 2 lock/unlock events for each child.");

@event_log = sort {$a->{etime} <=> $b->{etime}} @event_log;
my $last_event;
for (@event_log) {
    if (defined $last_event) {
        my $valid_next_event = ($last_event eq "UNLOCK_SUCCESS" ? "LOCK_SUCCESS" : "UNLOCK_SUCCESS");
        ok($_->{event} eq $valid_next_event, sprintf("Last lock event was a %s so we expected a to see %s, got a %s", $last_event, $valid_next_event, $_->{event}));
    }
    $last_event = $_->{event};
    printf("%s\t%s\t%s\n", $_->{etime}, $_->{pid}, $_->{event});
}


done_testing();

###

sub test_locking {
    my %params = @_;
    my $successful = delete $params{successful};
    die unless defined($successful);
    my $message = delete $params{message};
    die unless defined($message);

    my $lock = Genome::Sys->lock_resource(%params);
    if ($successful) {
        ok($lock,$message);
        if ($lock) { return $lock; }
    } else {
        ok(!$lock,$message);
    }
    return;
}

sub print_event {
    my $fh = shift;
    my $info = shift;
    my $msg  = shift;

    my ( $seconds, $ms ) = gettimeofday();
    $ms = sprintf("%06d",$ms);
    my $time = "$seconds.$ms";

    my $tp = sprintf( "%s\t%s\t%s\t%s", $time, $info, $$, $msg );

    print $fh $tp, "\n";
    print $tp, "\n";
}

