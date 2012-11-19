package Task;
use strict;
use ConfigFile;

=head1 SYNOPSIS

  my $task = Task->new($id, 'task.conf');

=cut

sub new
{
  my $self = bless {}, shift;
  $self->init(@_);
  $self
}

sub id   { $_[0]{id} }
sub name { $_[0]{name} }

sub init
{
  my ($self, $id, $filename) = @_;
  $self->{id} = $id;
  $self->{name} = $id;
  $self->{filename} = $filename;
  my $conf;
  eval {
    $conf = ConfigFile->new($filename);
    $conf->load;
    $self->{conf} = $conf->get_all;
  };
  if ($@){
    chomp $@;
    die "$@\nCan not create new task\n";
  }

  if ($conf->is_set('', 'name')){
    $self->{name} = $conf->get_var('', 'name');
  }
}

1;

