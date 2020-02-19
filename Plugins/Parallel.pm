package Plugins::Parallel;
use strict;

our $in_parallel = 0;

# Plugins::Parallel->on_prepare($task, $cur_ind, \@tasks, \@task_list);
sub on_prepare
{
  my $class = shift;
  my $task = shift;

  ## end parallel ##
  if (!$task->get_var('', 'in_parallel')) {
    $in_parallel = 0;
    return;
  }

  ## parallel ##
  local $in_parallel = 1;

  my @ret;
  my $i = $_[0]+1;
  for (; $in_parallel && $i < @{$_[1]}; $i++) {
    my $t = $_[1][$i];
    my $cur_list = [];
    if (('Plugins::'.$t->plugin)->can('on_prepare')) {
      ('Plugins::'.$t->plugin)->on_prepare($t, $i, $_[1], $cur_list);
    }
    else {
      push @$cur_list, $t;
    }
    push @ret, $cur_list if @$cur_list;
  }
  push @{$_[2]}, [@ret];
  $_[0] = $i - 1;
}

1
