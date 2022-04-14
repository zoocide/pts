package Plugins::Base;
use strict;
use Exporter 'import';
BEGIN{
  eval {
    require 'Time/HiRes.pm';
    Time::HiRes->import('time');
  };
}

our $VERSION = $::VERSION;

our @EXPORT = qw(
  print_out
  dbg1
  dbg2
  dprint
  dprint_t
  dprint_tr
  dtimer_reset
);

=head1 SYNOPSIS

  my $result = Plugins::PluginName->process($task, $task_database);
  print 'task ', ($result ? 'complete' : 'failed'), "\n";

  #########################

  use Plugins::Base v0.4;
  sub process {
    dbg1 and dprint("debug message");
    print_out("normal output\n");
  }

  #########################

  use Plugins::Base v0.4.1;

  dbg1 and dtimer_reset('timer1');
  #... do something ...
  dgb1 and dpirnt_t('timer1', "something is done");

=head1 DESCRIPTION

This is the base of all plugins.

=cut

use constant {
  dbg1 => main::dbg1(),
  dbg2 => main::dbg2(),
};

our $out;
our %timers;

sub print_out
{
  defined $out or return print @_;
  $out->push(@_);
}

sub dprint
{
  my $msg = join '', map main::clr_dbg()."DEBUG: $_".main::clr_end()."\n", split "\n", join '', @_;
  defined $out or return print $msg;
  $out->push($msg);
}

sub dprint_t
{
  my $timer = shift;
  my $t = sprintf '%.6f', time - $timers{$timer};
  print_out(main::clr_dbg()."DEBUG [${t}s]: ", @_, main::clr_end()."\n");
}

sub dprint_tr
{
  dprint_t(@_);
  dtimer_reset($_[0]);
}

sub dtimer_reset
{
  my $t = time;
  $timers{$_} = $t for @_;
}

sub process_wrp
{
  my $class = shift;
  local $out = shift;
  local %timers;
  $class->process(@_)
}

# $status = $class->process($task, $tasksDB);
sub process
{
  die $_[0].' is not implemented. Task \''.$_[1]->name."' can not be processed.\n";
}

1
