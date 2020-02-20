package Plugins::Base;
use strict;
use Exporter 'import';

our $VERSION = v0.4.0;

our @EXPORT = qw(
  print_out
  dprint
);

=head1 SYNOPSIS

  my $result = Plugins::PluginName->process($task, $task_database);
  print 'task ', ($result ? 'complete' : 'failed'), "\n";

=head1 DESCRIPTION

This is the base of all plugins.

=cut

our $out;
our %timers;

sub print_out
{
  defined $out or return print @_;
  $out->push(@_);
}

sub dprint
{
  my $msg = join '', map "DEBUG: $_\n", split "\n", join '', @_;
  defined $out or return print $msg;
  $out->push($msg);
}

sub process_wrp
{
  my $class = shift;
  local $out = shift;
  local %timers;
  $class->process(@_)
}

sub process
{
  die $_[0].' is not implemented. Task \''.$_[1]->name."' can not be processed.\n";
}

1
