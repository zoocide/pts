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

my $old_sigint;
our $terminated;

# my $stats = process_tasks(\@prepared_tasks);
# ## $stats = {all => [@all], failed => [@failed], skipped => [@skipped],}
sub process_tasks
{
  my $prepared = shift;
  my $output : shared = TasksOutput->new;
  $old_sigint = sub {
    $terminated = 1;
    die "terminated by the user\n";
  };
  my $ret = m_process_tasks($prepared, $output);
  $ret
}

sub m_process_tasks
{
  my $tasks = shift;
  my $output : shared = shift;
  $SIG{INT} = $old_sigint;
  my $is_master = $output->is_main_thread;

  my $stats = {};

  for my $task (@$tasks) {
    if (ref $task eq 'ARRAY') {
      ## process parallel tasks group ##
      # $task = [[@tasks], ...]
      if ($terminated) {
        for my $t (@$task) {
          my $rs = m_process_tasks($t, $output);
          push @{$stats->{$_}}, @{$rs->{$_}} for keys %$rs;
        }
        next
      }

      dbg1 and dprint("## start parallel section ##");
      my @thrs;
      local $SIG{INT} = sub {
        for (@thrs) {
          $_->kill('SIGINT') if $_->is_running;
        }
        $terminated = 1
      };
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
    main::process_task($task, $o, $stats, $terminated ? 'skipped' : ());
    $output->close($task->index);
  }
  $stats
}

1
