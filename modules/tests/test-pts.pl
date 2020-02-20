#!/usr/bin/perl -w
use strict;
use Test::More tests => 2;

my $pts = '../../bin/pts.pl';
my $plugins_dir = '-I.';
my $tasks_dir = '-Ttasks';

## launch capability testing ##
is(run_tasks('simple_1'), <<'EOS');
----- simple_1 -----
ok
ok.............simple_1
EOS

## several tasks launch ##
is(run_tasks(qw(simple_1 simple_1 simple_2)), <<'EOS');
----- simple_1 -----
ok
ok.............simple_1
----- simple_1 -----
ok
ok.............simple_1
----- simple_2 -----
simple_2:ok
ok.............simple_2

statistics:
num total    = 3
num complete = 3
num skipped  = 0
num failed   = 0
EOS

## test

sub run_tasks
{
  my $out = qx($^X $pts 2>&1 $plugins_dir $tasks_dir @_);
  $out
}
