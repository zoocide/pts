#!/usr/bin/perl
use strict;
use lib '..';
use Benchmark qw(cmpthese);
use Task;

my %h = ( task_id => 1 );
my $get_scalar = sub { 'task_id' };
my $id = Task::ID->new('task_id');
my $scalar = 'task_id';

print "Fetching data\n";
cmpthese -1, {
  #constant => sub {
  #  $h{task_id};
  #},
  scalar_variable => sub {
    $h{$scalar};
  },
  #sub_returns_scalar => sub {
  #  $h{&$get_scalar};
  #},
  'Task::ID->short_id' => sub {
    $h{$id->short_id};
  },
  'Task::ID->short_id with generation' => sub {
    $h{Task::ID->new('task_id')->short_id};
  }
};
