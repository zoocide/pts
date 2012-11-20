package Task;
use strict;
use ConfigFile;
use Exceptions;

=head1 SYNOPSIS

  my $task = Task->new($id, 'task.conf');

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

# throws: Exceptions::List
sub init
{
  my ($self, $id, $filename) = @_;
  $self->{id} = $id;
  $self->{name} = $id;
  $self->{filename} = $filename;
  my $conf;
  try{
    $conf = ConfigFile->new($filename);
    $conf->load;
    $conf->is_set('', 'plugin') || throw 'Exceptions::Exception' => "plugin is not specified in '$filename'";

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

1;

