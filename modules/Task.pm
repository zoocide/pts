package Task;
use strict;
use ConfigFile;
use Exceptions;
use File::Path qw(make_path);

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
sub conf   { $_[0]{conf} }
sub data_dir { $_[0]{data_dir} }

sub make_data_dir { make_path($_[0]{data_dir}) }

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
  $self->{filename} = $filename;
  $self->{data_dir} = $data_dir;
  my $conf;
  try{
    $conf = ConfigFile->new($filename, required => {'' => ['plugin']});
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

1;

