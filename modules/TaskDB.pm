package TaskDB;
use strict;
use Cwd qw(realpath);
use File::Spec::Functions qw(catfile);
use Exceptions;
use Task;

=head1 SYNOPSIS

  my $db = TaskDB->new('tasks_directory', ...);
  $db->add_tasks_dir('another_directory');
  my @tasks = $db->get_tasks(@task_IDs);
  my $bool = $db->task_exists($task_ID);
  my $task = $db->get_task($task_ID);

=cut

# throws: Exceptions::Exception
sub new
{
  my ($class, @tasks_dirs) = @_;
  @tasks_dirs = map realpath($_), @tasks_dirs;
  my $self = bless {
    dirs => [],
    tasks   => {},
  }, $class;
  $self->add_tasks_dir($_) for @tasks_dirs;
  $self
}

# throws: -
sub task_exists{ exists $_[0]{tasks}{$_[1]} }
sub all_task_ids { keys %{$_[0]{tasks}} }

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
  @wrong_ids && throw List => map "unknown task '$_'", @wrong_ids;
  map $self->{tasks}{$_}, @_
}

# $db->add_tasks_dir($dir);
# throws: Exceptions::Exception
sub add_tasks_dir
{
  my ($self, $dir) = @_;
  for my $t (m_load_tasks($dir)){
    $self->{tasks}{$t->id} = $t;
  }
  push $self->{dirs}, $dir;
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

