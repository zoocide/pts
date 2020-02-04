package Plugins::Simple2;
use base qw(Plugins::Base);
use Exceptions;

sub process
{
  my ($class, $task) = @_;
  print $task->name.":ok\n";
  1
}

1;

