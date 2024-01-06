package TaskDB;
use strict;
use Cwd qw(realpath);
use File::Spec::Functions qw(catfile);
use Exceptions;
use Task;

## debug stuff ##
our $dprint_prefix = __PACKAGE__.':';
BEGIN{*dprint = sub { main::m_dprint(map "$dprint_prefix $_\n", split /\n/, join '', @_) } if !exists &dprint}
BEGIN{
  ## Define non-inline version of dbg* functions. ##
  if (!exists &dbg1) { *dbg1 = sub () { $main::debug > 0 } }
  if (!exists &dbg2) { *dbg2 = sub () { $main::debug > 1 } }
}

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
    plugins => {}, #< { 'plugin' => $status, ... }
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
  dbg1 and dprint("new_task($_[0])");

  ## load task ##
  dbg2 and local $dprint_prefix = $dprint_prefix.'new_task:';
  dbg2 and dprint("make ID");
  my $tid = Task::ID->new($_[0]);
  $self->m_mk_new_task($tid);
}

# my $task = $db->get_task($task_spec_str);
# throws: Exceptions::Exception
sub get_task
{
  my $self = shift;
  # $_[0] - $task_spec_str
  # $_[1] - $light
  ## return loaded task ##
  return $self->{tasks}{$_[0]}[0] if exists $self->{tasks}{$_[0]};
  dbg2 and local $dprint_prefix = $dprint_prefix.'new_task:';
  my $tid = Task::ID->new($_[0]);
  my $id = $tid->id;
  return $self->{tasks}{$id}[0] if exists $self->{tasks}{$id};

  ## load task ##
  $self->m_mk_new_task($tid, $_[1])
}


# my $task = $db->get_task_light($task_spec_str);
# throws: Exceptions::Exception
sub get_task_light
{
  my $self = shift;
  return $self->get_task($_[0], 1);
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
    next if $tname !~ s/\.conf$//i || !$tname;

    $self->{task_files}{$tname} = {
      filename => $fname,
      data_dir => catfile($dir,'data',$tname),
    };
  }
  closedir $d;

  push @{$self->{dirs}}, $dir;
}

sub failed_plugins
{
  my $self = shift;
  return grep { !$self->{plugins}{$_} } keys %{$self->{plugins}};
}

# When $light is true, that means:
#   - do not load plugin.
#   - do not call on_task_create.
#   - do not add the task to the database.
sub m_mk_new_task
{
  my ($self, $tid, $light) = @_;

  ## load task ##
  my $short_id = $tid->short_id;
  my ($fname, $data_dir);
  if (exists $self->{task_files}{$short_id}) {
    ($fname, $data_dir) = @{$self->{task_files}{$short_id}}{qw(filename data_dir)};
  }
  elsif ($tid->dirs) {
    $fname = "$short_id.conf";
    -e $fname || throw Exception => "file '$fname' does not exist";
    $data_dir = catfile($tid->dirs, 'data', $tid->basename);
  }
  else {
    throw Exception => "unknown task '$short_id'";
  }
  dbg2 and dprint("make new ", ($light ? 'light ' : ''), "Task[", $tid, "]");
  my $task = Task->new($tid, $fname, $data_dir);
  if (!$light) {
    push @{$self->{tasks}{$tid->id}}, $task;
    if ($self->m_load_plugin($task)) {
      my $pc = $task->plugin_class;
      $pc->on_task_create($task, $self) if $pc->can('on_task_create');
    }
  }
  $task
}

sub m_load_plugin
{
  my ($self, $task) = @_;
  my $plugins = $self->{plugins};

  my $pname = $task->plugin;
  return $plugins->{$pname} if exists $plugins->{$pname};
  dbg1 and dprint("load plugin $pname");
  (my $req_pname = $pname) =~ s#::#/#g;
  eval {
    require "Plugins/$req_pname.pm"
  };
  if ($@){
    print $@;
  }
  return $plugins->{$pname} = !$@;
}

1;

__END__

=head1 METHODS

=over

=item all_task_ids()

Returns all the known task names.

=item new_task($task_spec_str)

Construct a new task from the provided task specification string.
It returns a L<Task> object.

=item get_task($task_spec_str)

It returns an existing task corresponded to the provided task specification string or create a new one.

=item get_task_light($task_spec_str)

It is similar to I<get_task>, but does not load a plugin, does not call I<on_task_create> and does not add the task to the database.

=item get_tasks($task_spec_str)

It returns all the existing tasks corresponded to the provided task specification string.

=item add_tasks_dir($dir)

Adds the directory to the search path.
It allows to load a task from the directory, with the basename specified only.

=item failed_plugins()

It returns a list of plugins that failed to load.

=back

=cut
