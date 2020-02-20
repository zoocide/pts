package TaskDB;
use strict;
use Cwd qw(realpath);
use File::Spec::Functions qw(catfile);
use Exceptions;
use Task;

=head1 SYNOPSIS

  my $db = TaskDB->new('tasks_directory', ...);
  $db->add_tasks_dir('another_directory');

  # $tid is a task specification string.
  # It may be a Task::ID object or something else.
  my $task = $db->new_task($tid);
  my @tasks = $db->get_tasks($tid);
  my $task = $db->get_task($tid);

=cut

# throws: Exceptions::Exception
sub new
{
  my ($class, @tasks_dirs) = @_;
  @tasks_dirs = map realpath($_), @tasks_dirs;
  my $self = bless {
    dirs => [], #< ['dir/with/tasks', ...]
    tasks   => {}, #< { 'canonical_id' => [$Task_obj, ...], ... }
    task_files => {}, #< { 'short_id' => {filename => $conf_filename,
                      #                   data_dir => $task_data_dir}, ... }
  }, $class;
  $self->add_tasks_dir($_) for @tasks_dirs;
  $self
}

# my @all_tids = $db->all_task_ids;
sub all_task_ids { keys %{$_[0]{task_files}} }

# my $task = $db->new_task($task_spec_str);
# throws: Exceptions::Exception
sub new_task
{
  my $self = shift;

  ## load task ##
  my $tid = Task::ID->new($_[0]);
  my $id = $tid->id;
  my $short_id = $tid->short_id;
  exists $self->{task_files}{$short_id} || throw Exception => "unknown task '$short_id'";
  my ($fname, $data_dir) = @{$self->{task_files}{$short_id}}{qw(filename data_dir)};
  my $task = Task->new($tid, $fname, $data_dir);
  push @{$self->{tasks}{$id}}, $task;
  $task
}

# my $task = $db->get_task($task_spec_str);
# throws: Exceptions::Exception
sub get_task
{
  my $self = shift;
  ## return loaded task ##
  return $self->{tasks}{$_[0]}[0] if exists $self->{tasks}{$_[0]};
  my $tid = Task::ID->new($_[0]);
  my $id = $tid->id;
  return $self->{tasks}{$id}[0] if exists $self->{tasks}{$id};

  ## load task ##
  my $short_id = $tid->short_id;
  exists $self->{task_files}{$short_id} || throw Exception => "unknown task '$short_id'";
  my ($fname, $data_dir) = @{$self->{task_files}{$short_id}}{qw(filename data_dir)};
  my $task = Task->new($tid, $fname, $data_dir);
  push @{$self->{tasks}{$id}}, $task;
  $task
}

# my @tasks = $db->get_tasks($tid);
# It returns all tasks with the same specification ($tid).
sub get_tasks
{
  my $self = shift;
  ## return loaded task ##
  return @{$self->{tasks}{$_[0]}} if exists $self->{tasks}{$_[0]};
  my $tid = Task::ID->new($_[0]);
  my $id = $tid->id;
  return @{$self->{tasks}{$id}} if exists $self->{tasks}{$id};
  ()
}

# $db->add_tasks_dir($dir);
# throws: Exceptions::Exception
sub add_tasks_dir
{
  my ($self, $dir) = @_;
  -d $dir || throw Exception => "'$dir' is not a directory";
  opendir (my $d, $dir) || throw Exception => "can not read directory '$dir': $!\n";

  for my $tname (readdir $d){
    my $fname = catfile($dir, $tname);
    next if $tname !~ s/\.conf$//i;

    $self->{task_files}{$tname} = {
      filename => $fname,
      data_dir => catfile($dir,'data',$tname),
    };
  }
  closedir $d;

  push @{$self->{dirs}}, $dir;
}

1;

