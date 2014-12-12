package Plugins::CompileTest;
use strict;
use base qw(Plugins::Base);
use Exceptions;
use File::Spec::Functions qw(catfile splitpath);
use File::chdir;
use File::Path qw(mkpath);
use File::HomeDir;
use File::Copy;
use ConfigFile;

=head1 DESCRIPTION

Test plugin.

=cut

##### initialization #####
my $global_config_file = catfile(File::HomeDir->my_home, '.pts', 'test-dvm.conf');
my $global_config = ConfigFile->new(
  $global_config_file,
  required => { '' => [qw(dvm_script_path test_suite_dir result_dir)] },
);

my $err;
try {
  $global_config->load;
}
catch {
  unshift @{$@}, Exceptions::Exception->new("In file '$global_config_file':");
  throw
} 'List';

## get global variables ##
my $tests_base_dir = $global_config->get_var('', 'test_suite_dir');
my $tests_out_base_dir = $global_config->get_var('', 'result_dir');
my $dvm = $global_config->get_var('', 'dvm_script_path');
-x $dvm or die "'$dvm' is not a DVM script. ",
               "Please edit '$global_config_file'.\n";
-d $tests_base_dir or die "'$tests_base_dir' is not a test suite directory. ",
                          "Please edit '$global_config_file'.\n";

##########################

sub process
{
  my ($class, $task, $db) = @_;

  my $action = lc $task->get_var('', 'action');
  my $ret = 1;

  if    ($action eq 'compile') { $ret = m_compile_dvm_test($task) }
  elsif ($action eq 'run'    ) { $ret = m_run_dvm_test($task, $db) }
  else { die "unknown action specified '$action'. Must be 'compile' or 'run'.\n" }

  $ret
}

sub m_compile_dvm_test
{
  my $task = shift;
  ## reload config with custom scheme ##
  $task->reload_config(
    multiline  => { '' => [qw(src)] },
    required   => { '' => [qw(src dvm_args dir out)] },
  );

  ## get source files ##
  my $test_dir = m_normalize_path($task->get_var('', 'dir'));
  my @src = map m_normalize_path($_), @{$task->get_var('', 'src')};
  my $out = $task->get_var('', 'out');

  my @orig_src = map catfile($tests_base_dir, $test_dir, $_), @src;
  my $work_dir = catfile($tests_out_base_dir, $test_dir);


  ## get dvm arguments ##
  my $dvm_args = $task->get_var('', 'dvm_args');

  ## Enter output directory ##
  $task->DEBUG("enter $work_dir");
  -e $work_dir || mkpath($work_dir);
  local $CWD = $work_dir;

  ## copy sources to work_dir ##
  for (0..$#src){
    $task->DEBUG("copy file '$orig_src[$_]' to '$src[$_]'");
    copy($orig_src[$_], $src[$_])
      || print "can not copy file '$orig_src[$_]' to '$src[$_]'\n";
  }

  ## Compile dvm test ##
  my $cmd = "$dvm $dvm_args $out";
  $task->DEBUG("executing: $cmd");
  system($cmd) == 0 && (-e $out || -e "$out.exe") or return 0;

  1
}

sub m_run_dvm_test
{
  my ($task, $db) = @_;
  ## reload config with custom scheme ##
  $task->reload_config(
    required   => { '' => [qw(compile_task dvm_args)] },
  );

  my ($compile_task, $dvm_args) = $task->get_vars('', 'compile_task', 'dvm_args');

  ## get compile_task ##
  my $ct = $db->get_task($compile_task);

  ## get out name and work_dir ##
  my $test_dir = m_normalize_path($ct->get_var('', 'dir'));
  my $out = $ct->get_var('', 'out');
  my $work_dir = catfile($tests_out_base_dir, $test_dir);

  ## enter work_dir ##
  $task->DEBUG("enter $work_dir");
  -d $work_dir || die "'$work_dir' is not a directory.\n";
  local $CWD = $work_dir;

  ## run dvm test ##
  my $cmd = "$dvm $dvm_args $out";
  $task->DEBUG("$cmd");
  my $output = `$cmd`;
  $? && return 0;

  m_analyze_output($task, $output)
}

sub m_analyze_output
{
  my ($task, $o) = @_;
  my @lines = split /\s*\r?\n\s*/, $o;
  shift @lines while @lines && $lines[0] !~ /^\s*=+\s*START OF /i;
  if (@lines < 2){
    $task->DEBUG('wrong output of the test');
    return 0;
  }

  my @failed;
  for (shift @lines; $lines[0] !~ /^\s*=+\s*END OF /i; shift @lines){
    @lines || return 0;
    if ($lines[0] =~ /^\s*(\w+)\s+-\s+(.*?)\s*$/){
      my $subtest = $1;
      my $status = $2;
      lc $status eq 'complete' || push @failed, $subtest;
    }
  }

  $task->DEBUG("failed subtests: ", join ', ', @failed);

  @failed == 0
}

# $path = m_normalize_path($path);
# Converts slashes into current OS path delimiter.
sub m_normalize_path
{
  catfile(split m#/#, $_[0]);
}

1;
