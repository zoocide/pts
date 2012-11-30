#!/usr/bin/perl -w
use strict;
use FindBin;
use lib "$FindBin::Bin/../modules";
use CmdArgs;
use Exceptions;
use TaskDB;

## load TaskDB ##
my $db;
try{ $db = TaskDB->new("$FindBin::Bin/../tasks") } string2exception make_exlist
catch{ push @{$@}, Exceptions::Exception->new('can not load tasks database'); throw };
CmdArgs::Types::TaskSet->set_db($db);

my $args = CmdArgs->declare(
  '0.1.0',
  options => {
    'quiet' => ['-q --quiet', 'dont print statistics and task name'],
    'list'  => ['-l --list',  'print all tasks in database'],
  },
  use_cases => {
    main => ['OPTIONS taskset:TaskSet', 'Process a set of tasks'],
    list => ['list', 'print all tasks in database'],
  },
);
$args->parse;

## list tasks ##
if ($args->use_case eq 'list'){
  print $_, "\n" for $db->all_task_ids;
  exit 0;
}

# it is assumed to use list of files in future
my @tasks = map { -f $_ ? $db->get_tasks(load_task_id_set($_)) : $db->get_task($_) }
                $args->arg('taskset');

my $quiet = $args->is_opt('quiet');

use lib "$FindBin::Bin/..";
my @failed;
for my $task (@tasks){
  print $task->name, ":\n" if !$quiet;
  my $res;
  try{
    eval 'use Plugins::'.$task->plugin.';';
    $@ && throw Exception => "plugin '".$task->plugin."' is not exist";#."\n$@\n";
    $res = ('Plugins::'.$task->plugin)->process($task, $db);
  }
  exception2string
  catch{
    print $@;
    $res = 0;
  };
  print $task->name, ' ', ($res ? 'complete' : 'failed ['.$task->id.']'), "\n" if !$res || !$quiet;
  push @failed, $task if !$res;
}

my $num_total  = @tasks;
my $num_failed = @failed;
my $num_ok     = $num_total - $num_failed;

print "\nstatistics:"
     ,"\nnum total    = ", $num_total
     ,"\nnum complete = ", $num_ok
     ,"\nnum failed   = ", $num_failed
     ,"\n"
     if !$quiet;



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

sub set_db { $db = $_[1] }

sub check
{
  my ($class, $filename) = @_;
  if (!-f $filename && !$db->task_exists($filename)){
    throw Exception => "file '$filename' is not exists";
    return 0;
  };
  1
}

