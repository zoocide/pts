package Plugins::Sequential;
use strict;

our $cont = 0;

# Plugins::Sequential->on_prepare($task, $cur_ind, \@all_tasks, \@task_list, $db);
sub on_prepare
{
  my $class = shift;
  my $task = shift;

  ## push int @all_tasks a seq task after current ##
  if ($task->get_var('', 'add_seq', 0)) {
    my $seq_task = $_[3]->get_task('seq');
    splice @{$_[1]}, $_[0]+1, 0, $seq_task;
  }

  ## end block ##
  if ($task->get_var('', 'end', 0)) {
    $cont = 0;
    return;
  }

  ## begin block ##
  local $cont = 1;

  my $i = $_[0]+1; #< skip current task
  for (; $cont && $i < @{$_[1]}; $i++) {
    my $t = $_[1][$i];
    if (('Plugins::'.$t->plugin)->can('on_prepare')) {
      ('Plugins::'.$t->plugin)->on_prepare($t, $i, $_[1], $_[2], $_[3]);
      next;
    }
    push @{$_[2]}, $t;
  }
  $_[0] = $i - 1;
}

1
