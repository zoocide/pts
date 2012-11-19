package TaskDB;
use strict;
use File::Spec::Functions qw(catfile);
use Exceptions;
use Task;

=head1 SYNOPSIS

  my $db = TaskDB->new('tasks_directory');
  my @tasks = $db->get_tasks(@task_IDs);

=cut

sub new
{
  my ($class, $dir) = @_;
  my $self = bless {
    dirname => $dir,
    tasks   => { map +($_->id, $_), m_load_tasks($dir) },
  }, $class;
}

sub get_tasks
{
  my $self = shift;
  my @wrong_ids = grep !exists $self->{tasks}{$_}, @_;
  @wrong_ids && die "unknown tasks:\n".(map "  $_\n", @wrong_ids);
  map $self->{tasks}{$_}, @_
}

sub m_load_tasks
{
  my ($dir) = @_;
  -d $dir || die "'$dir' is not a direcorty\n";
  my @tasks;
  opendir (my $d, $dir) || die "can not read directory '$dir': $!\n";
  for my $tname (readdir $d){
    my $file_name = catfile($dir, $tname);
    next if $tname !~ s/\.conf$//i;
    try{
      my $task = Task->new($tname, $file_name);
      push @tasks, $task;
    };
    catch{
      chomp $@; print "can not read '$tname' test: $@\n";
    };
  }
  closedir $d;
  @tasks
}

1;

