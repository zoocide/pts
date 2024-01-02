package Plugins::PluginHelp;
use strict;
use Exceptions;
use Plugins::Base v0.7.2;
use base qw(Plugins::Base);
use PtsConfig;
use File::Spec::Functions qw(catfile);

sub help_message
{
  my $class = shift;
  my $task = shift;
  return $task->get_var('', 'help_message') if $task->has_var('', 'help_message');
  my $name = $task->id;
  return "The task '$name' shows information about the first following task and interrupts execution."
    ."\nUse command 'pts help a_task' to see the description of 'a_task' task."
    ."\nUse command 'pts --help' to see the help message about 'pts' itself."
    ."\nUse command 'pts help:doc' to see the HTML documentation.";
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

  if ($self_task->get_var('', 'doc', 0)) {
    my $html_fname = catfile(PtsConfig::doc_dir, 'html', 'index.html');
    if (-f $html_fname) {
      system_timeout($html_fname, 1);
    } else {
      warn "File '$html_fname' does not exist.\n";
    }

    ## erase task list ##
    @{$_[0]} = ();
    @{$_[1]} = ();
    $$pind = 0;
    return;
  }

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

sub system_timeout
{
  my ($cmd, $timeout) = @_;
  $timeout >= 1 or die "timeout must be not less than 1 second\n";
  my $pid = fork;

  if (!$pid) {
    ## child ##
    dbg1 and dprint("system($cmd)");
    system($cmd);
    exit 0;
  }

  ## parent ##
  dbg1 and dprint("$pid forked child started");
  local $SIG{ALRM} = sub {
    dbg2 and dprint("killing the $pid forked process");
    kill 'KILL', $pid;
  };
  alarm($timeout);
  dbg2 and dprint("waiting for $pid forked child");
  my $wp = waitpid($pid, 0);
  if ($wp == $pid) {
    dbg2 and dprint("forked child $wp finished");
  }
  elsif ($wp == -1) {
    dbg2 and dprint("there is no $pid forked child");
  }
  else {
    dbg2 and dprint("an unexpected process $wp encountered");
  }
  alarm(0);
}

1
