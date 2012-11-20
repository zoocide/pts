package Plugins::TestPlugin;
use base qw(Plugins::Base);

=head1 DESCRIPTION

Test plugin.

=cut

sub process
{
  my ($class, $task) = @_;
  print "task '", $task->name, "' processing...\n";
  1
}

1;

