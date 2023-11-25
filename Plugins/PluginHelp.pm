package Plugins::PluginHelp;
use strict;
use Plugins::Base v0.7.2;
use base qw(Plugins::Base);

our $cont = 0;

sub help_message
{
  my $class = shift;
  my $task = shift;
  my $name = $task->id;
  return "The task '$name' shows information about the first following task and interrupts execution."
    ."\nUse command 'pts help a_task' to see the description of 'a_task' task."
    ."\nUse command 'pts --help' to see the help message about 'pts' itself.";
}

# Plugins::PluginHelp->on_prepare($task, $cur_ind, \@all_tasks, \@task_list, $db);
sub on_prepare
{
  my $class = shift;
  my $task = shift;
  my $pind = \shift;
  # $_[0] - $all_tasks
  # $_[1] - $tasks_list
  # $_[2] - $db

  my $next_task = $_[0][$$pind+1];
  my $help_msg =
    !defined $next_task ? $class->help_message($task) :
    $next_task->plugin_can('help_message') ? $next_task->plugin_class->help_message($next_task) :
    "The task '".($next_task->id)."' does not have a description.";

  print $help_msg, "\n";

  @{$_[0]} = ();
  @{$_[1]} = ();
  $$pind = 0;
  return;
}

1
