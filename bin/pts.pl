#!/bin/env perl
use strict;
#BEGIN { use Carp; $SIG{__WARN__} = sub {confess}; }
use FindBin;
use lib "$FindBin::RealBin/../modules";
use lib "$FindBin::RealBin/../modules/external";
our $VERSION;
BEGIN { $VERSION = v0.6.0; }
BEGIN{ *Task::dbg_level = sub () { 0 } }
BEGIN{ *TaskDB::dbg_level = sub () { 0 } }
use PtsConfig;
use CmdArgs;
use CmdArgs::BasicTypes;
use Exceptions;
use Exceptions::OpenFileError;
use Exceptions::TextFileError;
use TaskDB;
use File::Spec::Functions qw(catfile);

BEGIN{ eval{ require 'Time/HiRes.pm'; Time::HiRes->import('time') } }

our $script_start_time = time;

## load TaskDB ##
our $db;
try{ $db = TaskDB->new(PtsConfig->tasks_dir) } string2exception make_exlist
catch{ push @{$@}, Exceptions::Exception->new('can not load tasks database'); throw };

our $failed_fname;
our $num_procs;
my $debug = 0;
my $quiet;

our $args = CmdArgs->declare(
  sprintf('%vd',$VERSION),
  options => {
    tasks_dir => ['-T:Dir<<tasks_dir>>', 'Allow to process tasks from <tasks_dir>.'
                  .' It extends the tasks database with tasks from this directory.',
                  sub{ $db->add_tasks_dir($_) }],
    quiet => ['-q --quiet', 'Do not print statistics and task name.', \$quiet],
    debug => ['-D --debug', 'Print debug information. -DD produces even more information.', sub { $debug++ }],
    list  => ['-l --list',  'Print all tasks in database.'],
    stat  => ['-s --stat',  'Force to print statistics even for one task.'],
    plugins_dir => ['-I:Dir<<plugins_dir>>', 'Include plugins from directory.',
                    sub{ PtsConfig->add_plugins_parent_dir($_) }],
    failed  => ['--failed:<<file>>', 'Put failed tasks into <file>.',
                sub { $failed_fname = $_ }],
    ttime => ['--total-time', 'Print total time.'],
    force_mce => ['--mce', 'Force to use MCE parallel engine. It should be installed from CPAN.'],
    no_mce => ['--no-mce', "Don't use MCE parallel engine."],
    num_procs => ['--np:Int', 'Set the number of parallel workers. It makes sense only for the MCE engine.', \$num_procs],
  },
  groups => {
    OPTIONS => [qw(
      quiet stat debug
      tasks_dir plugins_dir
      failed
      ttime
      force_mce no_mce
      num_procs
    )],
  },
  use_cases => {
    main => ['OPTIONS taskset...', 'Process a set of tasks.'
             .' There is a tasks database, from which you can select tasks to execute.'
             .' Also you can sepcify files, containing tasks names.'],
    list => ['OPTIONS list', 'Print all tasks in database.'],
  },
  restrictions => [
    'force_mce|no_mce',
  ],
);
$args->parse;

## list tasks ##
if ($args->use_case eq 'list'){
  my @list = $db->all_task_ids;
  @list = map {my $t = $db->get_task($_); $t->task_dir.": $_"} @list if $debug;
  print $_, "\n" for sort @list;
  exit 0;
}

## check arguments ##
defined $num_procs && $num_procs <= 0 and die "the number of workers should be a positive integer\n";

## set constants ##
{my $d = $debug >= 1; *{dbg1} = sub () { $d } }
{my $d = $debug >= 2; *{dbg2} = sub () { $d } }
{my $q = $quiet; *{quiet} = sub () { $q } }
{my $v = $args->is_opt('force_mce'); *{force_mce} = sub () { $v } }
{my $v = $args->is_opt('no_mce'); *{no_mce} = sub () { $v } }

## load module with constants enabled ##
my $r = do 'pts-main.pm';
die $@ if $@;
die "could not do 'pts-main.pm': $!" if !defined $r;
$r
