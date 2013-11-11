package Plugins::Base;
use Task;

=head1 SYNOPSIS

  my $result = Plugins::PluginName->process($task, $task_database);
  print 'task ', ($result ? 'complete' : 'failed'), "\n";

=head1 DESCRIPTION

This is the base of all plugins.

=cut

sub process
{
  die $_[0].' is not implemented. Task \''.$_[1]->name."' can not be processed\n";
}

1;

