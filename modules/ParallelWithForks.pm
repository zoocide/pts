package ParallelWithForks;
use strict;
use warnings;
use ForkedChild;
use ForkedOutput;

BEGIN {
  *dprint = *main::dprint;
  *dbg1 = *main::dbg1;
  *dbg2 = *main::dbg2;
  *m_sleep = *main::m_sleep;
}
use constant windows => $^O eq 'MSWin32';

my $old_sigint;
our $terminated;

# my $stats = process_tasks(\@prepared_tasks);
# ## $stats = {all => [@all], failed => [@failed], skipped => [@skipped],}
sub process_tasks
{
  my $prepared = shift;
  STDOUT->autoflush(1);
  my $output = ForkedOutput->new;
  $old_sigint = sub {
    $terminated = 1;
    $SIG{INT} = sub {}; #< disable the handler to finish safely.
    die "terminated by the user\n";
  };
  my $ret = m_process_tasks($prepared, $output);
  defined and unlink $_ for $output->filenames;
  $ret
}

sub m_process_tasks
{
  my $tasks = shift;
  my $output = shift;
  $SIG{INT} = $old_sigint;
  my $is_master = $output->is_main_thread;

  my $stats = {};

  for my $task (@$tasks) {
    if (ref $task eq 'ARRAY') {
      ## process parallel tasks group ##
      # $task = [[@tasks], ...]
      if ($terminated) {
        m_process_tasks($_, $output) for @$tasks;
        next
      }

      dbg1 and dprint("## start parallel section ##");
      my @thrs;
      local $SIG{INT} = sub {
        # An unix terminal sends SIGINT to the foreground process group of that
        # terminal. The forked children are in the group and will receive the signal.
        # Windows fork emulation uses threads instead of processes, so the forked
        # children do not receive the SIGINT from the terminal.
        # It should be sended maually.
        if (windows) {
          for (@thrs) {
            $_->kill('SIGINT') if $_->is_running;
          }
        }
        $terminated = 1
      };
      push @thrs, ForkedChild->create(\&m_process_tasks, $_, $output) for @$task;
      for my $thr (@thrs) {
        if ($is_master) {
          $output->flush, m_sleep(0.1) while !$thr->is_joinable;
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
