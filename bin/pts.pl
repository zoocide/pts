#!/bin/env perl
use strict;
use FindBin;
use lib "$FindBin::Bin/../modules";
use lib "$FindBin::Bin/../modules/external";
our $VERSION;
BEGIN { $VERSION = v0.4.3; }
use PtsConfig;
use CmdArgs;
use CmdArgs::BasicTypes;
use Exceptions;
use Exceptions::OpenFileError;
use Exceptions::TextFileError;
use TaskDB;
use File::Spec::Functions qw(catfile);
use ForkedChild;
use ForkedOutput;

BEGIN{ eval{ require 'Time/HiRes.pm'; Time::HiRes->import('time') } }

use constant force_mce => 0;
#use constant use_mce => 0;# eval{ require ParallelWithMCE; 'ParallelWithMCE' } || (force_mce && die $@);
use constant use_mce => eval{ require ParallelWithMCE; 'ParallelWithMCE' } || (force_mce && die $@);

our $script_start_time = time;

## load TaskDB ##
our $db;
try{ $db = TaskDB->new(PtsConfig->tasks_dir) } string2exception make_exlist
catch{ push @{$@}, Exceptions::Exception->new('can not load tasks database'); throw };

our $failed_fname;
our $debug = 0;
our $quiet;

our $args = CmdArgs->declare(
  sprintf('%vd',$VERSION),
  options => {
    tasks_dir => ['-T:Dir<<tasks_dir>>', 'Allow to process tasks from <tasks_dir>.'
                  .' It extends the tasks database with tasks from this directory.',
                  sub{ $db->add_tasks_dir($_) }],
    quiet => ['-q --quiet', 'Do not print statistics and task name.', \$quiet],
    debug => ['-D --debug', 'Print debug information.', sub { $debug++ }],
    list  => ['-l --list',  'Print all tasks in database.'],
    stat  => ['-s --stat',  'Force to print statistics even for one task.'],
    plugins_dir => ['-I:Dir<<plugins_dir>>', 'Include plugins from directory.',
                    sub{ PtsConfig->add_plugins_parent_dir($_) }],
    failed  => ['--failed:<<file>>', 'Put failed tasks into <file>.',
                sub { $failed_fname = $_ }],
    ttime => ['--total-time', 'Print total time.'],
    #opt_use_mce => ['--mce', 'Force to use MCE parallel engine.', sub {...}],
    #opt_no_mce => ['--no-mce', "Don't use MCE parallel engine.", sub {...}],
  },
  groups => {
    OPTIONS => [qw(quiet stat debug tasks_dir plugins_dir failed ttime)],
  },
  use_cases => {
    main => ['OPTIONS taskset...', 'Process a set of tasks.'
             .' There is a tasks database, from which you can select tasks to execute.'
             .' Also you can sepcify files, containing tasks names.'],
    list => ['OPTIONS list', 'Print all tasks in database.'],
  },
);
$args->parse;

## list tasks ##
if ($args->use_case eq 'list'){
  my @list = $db->all_task_ids;
  @list = map {my $t = $db->get_task($_); $t->task_dir.": $_"} @list if $debug;
  print $_, "\n" for sort @list;
  exit 0;
}

## set constants ##
{my $d = $debug >= 1; *{dbg1} = sub () { $d } }
{my $d = $debug >= 2; *{dbg2} = sub () { $d } }
{my $q = $quiet; *{quiet} = sub () { $q } }

## load module with constants enabled ##
require 'pts-main.pm';
