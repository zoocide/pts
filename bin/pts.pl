#!/usr/bin/perl -w
use strict;
use FindBin;
use lib "$FindBin::Bin/../modules";
use PtsConfig;
use CmdArgs;
use CmdArgs::BasicTypes;
use Exceptions;
use TaskDB;

BEGIN{ eval{ require 'Time/HiRes.pm'; Time::HiRes->import('time') } }

## load TaskDB ##
my $db;
try{ $db = TaskDB->new(PtsConfig->tasks_dir) } string2exception make_exlist
catch{ push @{$@}, Exceptions::Exception->new('can not load tasks database'); throw };

my $args = CmdArgs->declare(
  '0.2.1',
  options => {
    tasks_dir => ['-T:Dir<<tasks_dir>>', 'allow to process tasks from <tasks_dir>',
                  sub{ $db->add_tasks_dir($_) }],
    'quiet' => ['-q --quiet', 'do not print statistics and task name'],
    'debug' => ['-D --debug', 'print debug information'],
    'list'  => ['-l --list',  'print all tasks in database'],
    'stat'  => ['-s --stat',  'force to print statistics even for one task'],
  },
  groups => {
    OPTIONS => [qw(quiet stat debug tasks_dir)],
  },
  use_cases => {
    main => ['OPTIONS taskset:TaskSet...', 'Process a set of tasks'],
    list => ['tasks_dir? list', 'Print all tasks in database'],
  },
);
$args->parse;

## list tasks ##
if ($args->use_case eq 'list'){
  print $_, "\n" for sort $db->all_task_ids;
  exit 0;
}

# it is assumed to use list of files in future
my @tasks = map { -f $_ ? $db->get_tasks(load_task_id_set($_)) : $db->get_task($_) }
                @{$args->arg('taskset')};

my $quiet = $args->is_opt('quiet');

my $start_time;
$start_time = time if $args->is_opt('debug');

use lib PtsConfig->plugins_parent_dir;
my @failed;
my @skipped;
for my $task (@tasks){
  if ($args->is_opt('debug')){
    $task->set_debug(1);
    print "\n";
  }
  print $task->name, ":\n" if !$quiet;
  $task->DEBUG_RESET('main_task_timer');
  my $res;
  try{
    eval 'use Plugins::'.$task->plugin.';';
    if ($@){
      $task->DEBUG($@);
      throw Exception => "plugin '".$task->plugin."' disabled";
    }
    $res = ('Plugins::'.$task->plugin)->process($task, $db);
  }
  exception2string
  catch{
    print $@;
    $res = 0;
  };
  $task->DEBUG_T('main_task_timer', 'task \''.$task->name.'\' finished');

  my $status;
  if ($res eq 'skipped'){
    $status = 'skipped';
    push @skipped, $task;
  } elsif ($res){
    $status = 'complete';
  } else {
    $status = 'failed ['.$task->id.']';
    push @failed, $task;
  }
  print $task->name, ' ', $status, "\n" if !$res || !$quiet;
}

print "\nDEBUG: total execution time = ", time - $start_time, "\n"
  if $args->is_opt('debug');

my $num_total  = @tasks;
my $num_failed = @failed;
my $num_skipped = @skipped;
my $num_ok     = $num_total - ($num_failed + $num_skipped);

print "\nstatistics:"
     ,"\nnum total    = ", $num_total
     ,"\nnum complete = ", $num_ok
     ,"\nnum skipped  = ", $num_skipped
     ,"\nnum failed   = ", $num_failed
     ,"\n"
     if $args->is_opt('stat') || (!$quiet && @tasks > 1);

exit 1 if @failed;

##### END #####

sub load_task_id_set
{
  my $filename = shift;
  open(my $f, '<', $filename) || die "can not open file '$filename': $!\n";
  ### rules ###
  #1)  # comment
  #2)  \#name  => '#name'
  #3)  \\#name => '\#name'
  my @lines = map { s/^\s+//; s/^#.*//; s/^\\#/#/; s/^\\\\/\\/; s/\s+$//; $_ ? $_ : () } <$f>;
  close $f;
  @lines
}



package CmdArgs::Types::TaskSet;
use Exceptions;

sub check
{
  my ($class, $filename) = @_;
  if (!-f $filename && !$db->task_exists($filename)){
    throw Exception => "Task '$filename' does not exist";
    return 0;
  };
  1
}

