package Plugins::Sequential;
use strict;

our $cont = 0;

sub help_message
{
  my $class = shift;
  my $task = shift;
  my $name = $task->id;
  return $task->get_var('', 'help_message', undef) //
    "The task '$name' manages the tasks sequencies to be executed".
    " sequentally inside a parallel region.";
}

# Plugins::Sequential->on_prepare($task, $cur_ind, \@all_tasks, \@task_list, $db);
sub on_prepare
{
  my $class = shift;
  my $task = shift;
  my $pind = \shift;
  # $_[0] - $all_tasks
  # $_[1] - $tasks_list
  # $_[2] - $db

  ## push into @all_tasks a seq task after the current ##
  # It is used in task end_seq_seq to start a new section immediately.
  if ($task->get_var('', 'add_seq', 0)) {
    my $seq_task = $_[2]->get_task('seq');
    splice @{$_[0]}, $$pind+1, 0, $seq_task;
  }

  ## end block ##
  if ($task->get_var('', 'end', 0)) {
    $cont = 0;
    return;
  }

  ## begin block ##
  local $cont = 1;

  my $i = $$pind+1; #< skip current task
  for (; $cont && $i < @{$_[0]}; $i++) {
    my $t = $_[0][$i];
    if (('Plugins::'.$t->plugin)->can('on_prepare')) {
      ('Plugins::'.$t->plugin)->on_prepare($t, $i, @_);
      next;
    }
    push @{$_[1]}, $t;
  }
  $$pind = $i - 1;
}

1
