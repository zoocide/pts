package TaskDB;
use strict;
use Cwd qw(realpath);
use File::Spec::Functions qw(catfile);
use Exceptions;
use Task;

=head1 SYNOPSIS

  my $db = TaskDB->new('tasks_directory');
  my @tasks = $db->get_tasks(@task_IDs);

=cut

# throws: Exceptions::Exception
sub new
{
  my ($class, $tasks_dir) = @_;
  my $dir = realpath($tasks_dir);
  $dir || throw Exception => "path '$tasks_dir' not exists";
  my $self = bless {
    dirname => $dir,
    tasks   => { map +($_->id, $_), m_load_tasks($dir) },
  }, $class;
}

# throws: -
sub task_exists{ exists $_[0]{tasks}{$_[1]} }

# throws: Exceptions::Exception
sub get_task
{
  my $self = shift;
  exists $self->{tasks}{$_[0]} || throw Exception => "unknown task '$_[0]'";
  $self->{tasks}{$_[0]}
}

# throws: Exceptions::List
sub get_tasks
{
  my $self = shift;
  my @wrong_ids = grep !exists $self->{tasks}{$_}, @_;
  @wrong_ids && die (join '', map "unknown task '$_'\n", @wrong_ids);
  map $self->{tasks}{$_}, @_
}

# throws: Exceptions::Exception
sub m_load_tasks
{
  my ($dir) = @_;
  -d $dir || throw Exception => "'$dir' is not a directory";
  my @tasks;
  opendir (my $d, $dir) || throw Exception => "can not read directory '$dir': $!\n";

  for my $tname (readdir $d){
    my $file_name = catfile($dir, $tname);
    next if $tname !~ s/\.conf$//i;
    try{
      my $task = Task->new($tname, $file_name, catfile($dir,'data',$tname));
      push @tasks, $task;
    }
    catch{
      print $@->msg, "\n";
    } 'Exceptions::List';
  }
  closedir $d;
  @tasks
}

1;

