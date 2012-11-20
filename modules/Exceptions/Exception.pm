package Exceptions::Exception;

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
  $_[0]{msg} = defined $_[1] ? $_[1] : '';
}

1;

