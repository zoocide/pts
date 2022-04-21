#!/bin/env perl
use strict;
use Test::More tests => 25;
use File::Spec::Functions qw(catfile);
BEGIN { eval 'use Time::HiRes qw(time);' }

my @user_args = @ARGV;
my $pts = '../../bin/pts.pl';
our $plugins_dir = '-I.';
our $tasks_dir = '-Ttasks';
my $out_dir = 'output';
my $make_reference = 0;

my %tests = (
  # $test_id => {
  #   out_fname = $out_fname,
  # },
);

## launch capability testing ##
test_run('t1', qw(simple_1));

## several tasks launch ##
test_run('t2', qw(simple_1 simple_1 simple_2));

## task with arguments ##
test_run('t_args', qw(simple_2 simple_2:name=foo simple_2:name=bar));

## test task specification by path ##
test_run('path_task', qw(./simple_1 tasks/simple_2 ./tasks/simple_2));
test_run('path_task_set', qw(./task.set tasks/task.set));
test_run('path_task_set_spec', qw(simple_2 ./simple_2));

## test .ptsconfig ##
{
  local $plugins_dir = '';
  local $tasks_dir = '';
  test_run('.ptsconfig', qw(simple_2 ./simple_2));
}

## test command: parallel ##
my @tasks = map "t_par:name=t$_,n=$_", 1..3;
my $time_beg = time;
test_run('t_par_s', @tasks);
my $time1 = time;
test_run('t_par_p', 'parallel', @tasks);
my $time2 = time - $time1;
$time1 -= $time_beg;
cmp_files($tests{t_par_s}{out_fname}, $tests{t_par_p}{out_fname});
ok($time1 > $time2, "seq time $time1 > par time $time2");

## test command: seq ##
my @tasks1 = map "t_seq:name=t1,id=$_", 1..10;
my @tasks2 = map "t_seq:name=t2,id=$_", 11..20;
$time_beg = time;
test_run('t_seq_s', @tasks1, @tasks2);
$time1 = time;
test_run('t_seq_p', 'parallel', 'seq', @tasks1, 'end_seq_seq', @tasks2);
$time2 = time - $time1;
$time1 -= $time_beg;
cmp_files($tests{t_seq_s}{out_fname}, $tests{t_seq_p}{out_fname});
note("seq time = $time1; par time = $time2");

sub run_tasks
{
  my $out = qx($^X $pts 2>&1 $plugins_dir $tasks_dir @user_args @_);
  $out
}

sub read_file
{
  my $fname = shift;
  open my $f, '<', $fname or die "cannot read file '$fname': $!\n";
  my $text = join '', <$f>;
  close $f;
  $text
}

sub test_run
{
  my $test_id = shift;
  exists $tests{$test_id} and die "test $test_id already exists";

  my $out_fname = catfile($out_dir, "$test_id.txt");
  $tests{$test_id}{out_fname} = $out_fname;

  my $out = run_tasks(@_);
  is($?, 0, "$test_id: run_tasks()");
  diag($out) if $?;
  if ($make_reference) {
    open my $f, '>', $out_fname or die "cannot open '$out_fname': $!";
    print $f $out;
    close $f;
  }
  my $pref = "$test_id: check";
  eval {
    my $ref = read_file($out_fname);
    is($out, $ref, $pref);
  };
  if ($@) {
    diag("$pref: $@");
    fail($pref);
  }
}

sub cmp_files
{
  my ($fname1, $fname2) = @_;
  eval {
    is(read_file($fname1), read_file($fname2));
  };
  if ($@) {
    diag($@);
    fail('cmp_files');
  }
}
