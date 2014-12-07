package Task;
use strict;
use ConfigFile;
use ConfigFileScheme;
use Exceptions;
use File::Path qw(make_path);
BEGIN{
  eval {
    require 'Time/HiRes.pm';
    Time::HiRes->import('time');
  };
}

=head1 SYNOPSIS

  my $task = Task->new($id, 'task.conf');

  # reload config file of the task using your scheme.
  $task->reload_config(multiline => 1, ...);

  $task->make_data_dir($task_dir);

  chdir $task->data_dir;

  my ($var1, $var2) = $task->get_vars('group', 'var1', 'var2');

  ======== DEBUG ========
  $task->DEBUG(@messages_to_print);      ##< print debug messages
  $task->DEBUG_RESET(1, 2, 3);           ##< reset timers 1, 2, 3
  $task->DEBUG_T(2, @messages);          ##< print messages and time of timer 2
  $task->DEBUG_TR(2, @messages);         ##< print messages and time of timer 2; reset timer 2
=cut

sub new
{
  my $self = bless {}, shift;
  $self->init(@_);
  $self
}

sub id     { $_[0]{id} }
sub name   { $_[0]{name} }
sub plugin { $_[0]{plugin} }
sub conf   { $_[0]{conf} }
sub data_dir { $_[0]{data_dir} }
sub set_debug { $_[0]{debug} = $_[1] }

sub make_data_dir { make_path($_[0]{data_dir}) }

sub DEBUG   { $_[0]->{debug} && print 'DEBUG: ', @_[1..$#_], "\n" }
sub DEBUG_T
{
  return if !$_[0]->{debug};
  my $t = sprintf '%.6f', time - $_[0]->{debug_time}{$_[1]};
  print "DEBUG [${t}s]: ", @_[2..$#_], "\n";
}
sub DEBUG_RESET{ my $t = time; $_[0]->{debug_time}{$_} = $t for @_[1..$#_] }
sub DEBUG_TR{ $_[0]->DEBUG_T(@_[1..$#_]); $_[0]->DEBUG_RESET($_[1]) }

# my $var = $task->get_var('group_name', 'var_name');
# throws: Exceptions::Exception
sub get_var
{
  if (!exists $_[0]{conf}{$_[1]}{$_[2]}){
    my $fname = $_[0]->{filename};
    throw Exception => "$fname: variable '".($_[1] ? "$_[1]::" : '')."$_[2]' is not set";
  }
  $_[0]{conf}{$_[1]}{$_[2]}
}

# my @vars = $task->get_vars('group_name', @var_names);
# throws: Exceptions::List
sub get_vars
{
  my $self = shift;
  my $gr   = shift;
  my @missed = grep !exists $self->{conf}{$gr}{$_}, @_;
  if (@missed){
    $gr .= '::' if $gr;
    my $fname = $self->{filename};
    throw List => map Exceptions::Exception->new("$fname: variable '$gr$_' is not set"), @missed;
  }
  map $self->{conf}{$gr}{$_}, @_;
}

# throws: Exceptions::List
sub init
{
  my ($self, $id, $filename, $data_dir) = @_;
  $self->{id} = $id;
  $self->{name} = $id;
  $self->{debug} = 0;
  $self->{filename} = $filename;
  $self->{data_dir} = $data_dir;
  my $conf;
  try{
    $conf = ConfigFile->new($filename, required => {'' => ['plugin']});
    $conf->skip_unrecognized_lines(1);
    $conf->load;

    $self->{ conf } = $conf->get_all;
    $self->{plugin} = $conf->get_var('', 'plugin');
    $self->{ name } = $conf->get_var('', 'name') if $conf->is_set('', 'name');
  }
  make_exlist
  catch{
    push @{$@}, Exceptions::Exception->new("Can not create task '$id'");
    throw;
  };
}

# $task->reload_config(ConfigFileScheme_obj);
# or
# $task->reload_config(multiline => 1, ...);
sub reload_config
{
  my $self = shift;
  my $scheme = ($_[0] && eval {$_[0]->isa('ConfigFileScheme')})
             ? shift
             : ConfigFileScheme->new(@_);
  my $conf = ConfigFile->new($self->{filename}, $scheme);
  $conf->load;
  $self->{ conf } = $conf->get_all;
}

1;

