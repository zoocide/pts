package Plugins::RunChild;
use base qw(Plugins::Base);
use Exceptions;

sub process
{
  my ($class, $task) = @_;
  print "task '", $task->name, "' [$$] starts a child...\n";
  `./child.exe`;
  $? == 0 or die "Child process failed\n";
  1
}

1;

