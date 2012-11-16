package Exceptions::TextError;
use base qw(Exception);

sub init
{
  my ($self, $line, $msg) = @_;
  $self->SUPER::init($msg);
  $self->{line} = $line;
}

sub line { $_[0]{line} }

1;

