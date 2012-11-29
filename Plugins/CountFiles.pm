package Plugins::CountFiles;
use strict;
use base qw(Plugins::Base);
use File::Find;
use File::Spec::Functions qw(catfile rel2abs);
BEGIN{ eval{ use Time::HiRes qw(time) } } ##< used only for debug
use Exceptions;
use Exceptions::OpenFileError;
use ConfigFile;

=head1 DESCRIPTION

  parameters:
  type      |< 'init'  - remember the structure of the directory
  base      |< specify id of the 'check' task
  -------------------
  type      |  'check' - find differences of structure relative to initial structure
  scan_dir  |< specify the working directory
  -------------------

  Find all new and removed files in the specified directory.
  It should be called at first with 'init' type to initialize data.

=cut

my ($_debug_, $_t_) = (1); ##< print debug info

sub process
{
  my ($class, $task, $taskDB) = @_;
  m_reset_time();

  my $type = $task->get_var('' => 'type');
  (grep $type eq $_, qw(init check)) || throw Exception => "wrong type '$type'";

  # if 'init', replace task with it's base.
  $task = $taskDB->get_task($task->get_var('' => 'base')) if $type eq 'init';

  my $work_dir = $task->get_var('', 'scan_dir');
  my $data_fname = catfile($task->data_dir, 'files.txt');
  $task->make_data_dir;

  ## check params ##
  -d $work_dir || throw Exception => "'$work_dir' is not a dirctory";
  $work_dir = rel2abs($work_dir);
  my $l = length $work_dir;

  my $conf = ConfigFile->new(
    $data_fname,
    multiline => { '' => [qw(files)] },
    required  => { '' => [qw(files)] },
  );
  # get files in working directory
  my @found = sort(m_files_in_dir($work_dir));
  m_debug(scalar(@found)," files found");

  if ($type eq 'init'){
  ## 'init' case ##
    eval{
      $conf->load;
      push @found, grep $work_dir ne substr($_, 0, $l), @{$conf->get_var('', 'files')};
    };

    $conf->set_var('files', [@found]);
    $conf->save;
  }
  else{
  ## 'check' case ##
    $conf->load;
    m_debug("saved data (", scalar @{$conf->get_var('' => 'files')}, ") loaded");
    my @files = sort grep $work_dir eq substr($_, 0, $l), @{$conf->get_var('' => 'files')};
    m_debug("files are filtered for current dir");
    my @new_files = grep !m_arr_contains(\@files, $_), @found;
    m_debug("new files found");
    my @mis_files = grep !m_arr_contains(\@found, $_), @files;
    m_debug("removed files found");
    @new_files && print "new files:\n"    , map "  $_\n", @new_files;
    @mis_files && print "removed files:\n", map "  $_\n", @mis_files;
  }

  1
}

sub m_files_in_dir
{
  my $work_dir = shift;
  my @found;
  find(
    sub {
      my $fname = $_; #$File::Find::name;
      push @found, rel2abs($fname);
    },
    $work_dir
  );
  @found
}

sub m_arr_contains
{
  my ($arr, $elem) = @_;
  my ($b, $e, $i) = (0, $#$arr);
  while ($e - $b > 1){
    $i = int($b + $e)/2;
    if    ($arr->[$i] lt $elem){ $b = $i }
    elsif ($arr->[$i] eq $elem){ return 1 }
    else{ $e = $i }
  }
  $arr->[$b] eq $elem || $arr->[$e] eq $elem
}

sub m_reset_time{ $_t_ = time }
sub m_debug
{
  $_t_ = sprintf '%.6f',time() - $_t_;
  $_debug_ && print "DEBUG [${_t_}s]: ", @_, "\n";
  $_t_ = time;
}

1;

