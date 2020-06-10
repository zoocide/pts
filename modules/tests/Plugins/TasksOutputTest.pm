package Plugins::TasksOutputTest;
use v5.10;
use Plugins::Base;
use base qw(Plugins::Base);

sub process
{
  my ($class, $task, $db) = @_;
  dbg1 and dprint("debug print");
  print_out($task->name.": $_\n"), m_sleep(0.5) for 1..$task->get_var('', 'n', 3);
  1
}

sub m_sleep
{
  select undef, undef, undef, shift;
}

1
