package Exceptions;
use base qw(Exporter);
our @EXPORT;
@EXPORT = qw(try throw catch);

=head1 SYNOPSIS

  use Exceptions;

  try {
    ## do something ##
    ...
    # throw exception of 'Exception' type
    throw Exception "message";
    ...
    # throw exception of 'MyException' type
    throw MyException => $arg1, $arg2, $arg3;
  };

  catch {
    ## catch exception of 'MyException' type ##
  } 'MyException';

  catch {
    ## catch exception of 'Exception' type ##
    my $msg = $_[0]->msg;    ##< obtain message from exception
  } 'Exception';

  catch {
    ## catch all exceptions ##
  };

=cut

sub throw
{
  die $_[0] if ref $_[0];
  die +(shift)->new(@_);
}

sub try (&)
{
  eval { &{$_[0]} };
}

sub catch (&;$;$)
{
  return unless $@;
  my ($sub, $type) = @_;
  return unless !$type || $@->isa($type);
  &$sub($@);
  $@ = undef;
}



package Exception;

=head1 DESCRIPTION

It is the base class for exceptions.

=cut

sub new
{
  my $self = bless {}, shift;
  $self->init(@_);
  $self
}

sub msg { $_[0]{msg} }

sub init
{
  $_[0]{msg} = $_[1];
}

1;

