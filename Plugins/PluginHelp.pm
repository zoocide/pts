package Plugins::PluginHelp;
use strict;
use Exceptions;
use Plugins::Base v0.7.2;
use base qw(Plugins::Base);

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
  my $self_task = shift;
  my $pind = \shift;
  # $_[0] - $all_tasks - input list of tasks
  # $_[1] - $tasks_list - output execution tree
  # $_[2] - $db



  my $i = $$pind + 1; #< next task index;
  my $next_task = $_[0][$i];
  if (defined $next_task) {
    $class->print_help_message($next_task);
  }
  else {
    $class->print_help_message($self_task);
  }

  ## erase task list ##
  @{$_[0]} = ();
  @{$_[1]} = ();
  $$pind = 0;
}

sub print_help_message
{
  my $class = shift;
  my $task = shift;
  my $msg;
  if ($task->plugin_can('help_message')) {
    try { $msg = $task->plugin_class->help_message($task) }
    catch { $msg = $@ };
  }
  else {
    $msg = "The task '".($task->id)."' does not have a description.";
  }
  print $msg, "\n";
}

1
