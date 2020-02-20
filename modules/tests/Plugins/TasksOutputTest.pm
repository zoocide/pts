package Plugins::TasksOutputTest;
use v5.10;
use Plugins::Base;
use base qw(Plugins::Base);

sub process
{
  my ($class, $task, $db) = @_;
  print_out($_, "\n"), sleep(1) for 1..$task->get_var('', 'n', 3);
  1
}

1
