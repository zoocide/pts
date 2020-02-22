package Plugins::Parallel;
use strict;

our $in_parallel = 0;

# Plugins::Parallel->on_prepare($task, $cur_ind, \@all_tasks, \@task_list, $db);
sub on_prepare
{
  my $class = shift;
  my $task = shift;
  my $pind = \shift;
  my $all_tasks = shift;
  my $task_list = shift;

  ## end parallel ##
  if (!$task->get_var('', 'in_parallel')) {
    $in_parallel = 0;
    return;
  }

  ## parallel ##
  local $in_parallel = 1;

  my @ret;
  my $i = $$pind+1;
  for (; $in_parallel && $i < @$all_tasks; $i++) {
    my $t = $all_tasks->[$i];
    my $cur_list = [];
    if (('Plugins::'.$t->plugin)->can('on_prepare')) {
      ('Plugins::'.$t->plugin)->on_prepare($t, $i, $all_tasks, $cur_list, @_);
    }
    else {
      push @$cur_list, $t;
    }
    push @ret, $cur_list if @$cur_list;
  }
  push @$task_list, [@ret];
  $$pind = $i - 1;
}

1
