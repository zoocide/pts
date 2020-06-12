package ParallelWithThreads;
use strict;
use warnings;
use threads;
use TasksOutput;

BEGIN {
  *dprint = *main::dprint;
  *dbg1 = *main::dbg1;
  *dbg2 = *main::dbg2;
  *m_sleep = *main::m_sleep;
}

# my $stats = process_tasks(\@prepared_tasks);
# ## $stats = {all => [@all], failed => [@failed], skipped => [@skipped],}
sub process_tasks
{
  my $prepared = shift;
  my $output : shared = TasksOutput->new;
  my $ret = m_process_tasks($prepared, $output);
  $ret
}

sub m_process_tasks
{
  my $tasks = shift;
  my $output : shared = shift;
  my $is_master = $output->is_main_thread;

  my $stats = {};

  for my $task (@$tasks) {
    if (ref $task eq 'ARRAY') {
      ## process parallel tasks group ##
      # $task = [[@tasks], ...]
      dbg1 and dprint("## start parallel section ##");
      my @thrs;
      push @thrs, threads->create({context => 'list'}, \&m_process_tasks, $_, $output) for @$task;
      for my $thr (@thrs) {
        if ($is_master) {
          $output->flush, m_sleep(0.0001) while !$thr->is_joinable;
        }
        my ($rs) = $thr->join;
        $output->flush;
        push @{$stats->{$_}}, @{$rs->{$_}} for keys %$rs;
      }
      dbg1 and dprint("## end parallel section ##");
      next;
    }

    ## process task ##
    my $o = $output->open($task->index);
    main::process_task($task, $o, $stats);
    $output->close($task->index);
  }
  $stats
}

1
