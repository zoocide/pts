package Plugins::PluginHelp;
use strict;
use Exceptions;
use Plugins::Base v0.7.2;
use base qw(Plugins::Base);
use PtsConfig;
use File::Spec::Functions qw(catfile);
use MyConsoleColors qw(:ALL_COLORS);

my ($ci, $cc, $ce) = (clr_br_blue, clr_br_yellow, clr_end);

sub help_message
{
  my $class = shift;
  my $task = shift;
  return $task->get_var('', 'help_message') if $task->has_var('', 'help_message');
  my $name = $task->id->short_id;
  return "The task $ci$name$ce shows information about the first following task and interrupts execution."
    ."\nUse command ${cc}pts help a_task$ce to see the description of ${ci}a_task$ce task."
    ."\nUse command ${cc}pts --help$ce to see the help message about ${ci}pts$ce itself."
    ."\nUse command ${cc}pts help:doc$ce to see the HTML documentation.";
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
    my $conf = $_[2]->get_task('config')->data;
    my $browser = $conf->get_var('help', 'browser', '');
    my $timeout = $conf->get_var('help', 'timeout', 1);
    if (-f $html_fname) {
      #system_timeout($html_fname, 1);
      $browser = qq("$browser" ) if $browser;
      if (my $r = system_timeout_simple("$browser$html_fname", $timeout)) {
        ## error ##
        print_out("You can set the browser to use with the command ${cc}pts \"config:help::browser='a path/to a browser'\"$ce.\n");
        print_out("Also, if you use a console browser (like ${ci}lynx$ce) it is necessary to disable timeout with the command ${cc}pts config:help::timeout=0$ce.\n");
        print_out("Otherwise, it will be killed after a short time.\n");
      }
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

sub system_timeout_simple
{
  my ($cmd, $timeout) = @_;
  local $SIG{ALRM} = sub {
    throw Exception => 'timeout';
  };
  my $ret = 0;
  try {
    alarm($timeout);
    dbg1 and dprint("system($cmd)");
    $ret = system($cmd);
    alarm(0);
  }
  catch {
    dbg2 and dprint($@);
  } 'Exception',
  catch {
    print_out("$@");
    $ret = -1;
  };
  $ret
}

1
