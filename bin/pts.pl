#!/usr/bin/perl -w
use strict;
use lib '../modules';
use CmdArgs;
use Exceptions;
use TaskDB;

try{

my $db = TaskDB->new('../tasks');
CmdArgs::Types::TaskSet->set_db($db);

my $args = CmdArgs->declare(
  '0.0.1',
  use_cases => {
    main => ['taskset:TaskSet', 'Process a set of tasks'],
  },
);
$args->parse;

my @tasks = map $db->get_tasks(load_task_id_set($_)), $args->arg('taskset');
#use Data::Dumper;
#print Dumper(\@tasks);

use lib '..';
my @failed;
for my $task (@tasks){
  print $task->name, ":\n";
  my $res;
  try{
    eval 'use Plugins::'.$task->plugin.';';
    $@ && throw 'Exceptions::Exception' => "plugin '".$task->plugin."' is not exist";
    $res = ('Plugins::'.$task->plugin)->process($task);
  }
  exception2string
  catch{
    print $@;
    $res = 0;
  };
  print "task '", $task->name, "' ", ($res ? 'complete' : 'failed'), "\n";
  push @failed, $task if !$res;
}

my $num_total  = @tasks;
my $num_failed = @failed;
my $num_ok     = $num_total - $num_failed;

print "\nstatistics:"
     ,"\nnum total    = ", $num_total
     ,"\nnum complete = ", $num_ok
     ,"\nnum failed   = ", $num_failed
     ,"\n";

}
exception2string;


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

our $db;

sub set_db { $db = $_[1] }

sub check
{
  my ($class, $filename) = @_;
  if (!-f $filename){
    print "file '$filename' is not exists\n";
    return 0;
  };
  1
}

