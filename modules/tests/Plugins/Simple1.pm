package Plugins::Simple1;
use base qw(Plugins::Base);
use Exceptions;

sub process
{
  my ($class, $task) = @_;
  print "ok\n";
  1
}

1;

