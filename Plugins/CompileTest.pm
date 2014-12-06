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
our $global_config = ConfigFile->new(
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

##########################

sub process
{
  my ($class, $task) = @_;

  ## reload config with custom scheme ##
  $task->reload_config(
    multiline  => { '' => [qw(src dvm_args)] },
    join_lines => { '' => [qw(dvm_args)] },
    required   => { '' => [qw(src dvm_args dir)] },
  );

  ## get global variables ##
  my $tests_base_dir = $global_config->get_var('', 'test_suite_dir');
  my $tests_out_base_dir = $global_config->get_var('', 'result_dir');
  my $dvm = $global_config->get_var('', 'dvm_script_path');
  -x $dvm or die "'$dvm' is not a DVM script. ",
                 "Please edit '$global_config_file'.\n";
  -d $tests_base_dir or die "'$tests_base_dir' is not a test suite directory. ",
                            "Please edit '$global_config_file'.\n";

  ## get source files ##
  my $test_dir = m_normalize_path($task->get_var('', 'dir'));
  my @src = map m_normalize_path($_), @{$task->get_var('', 'src')};
  my @orig_src = map catfile($tests_base_dir, $test_dir, $_), @src;
  my $work_dir = catfile($tests_out_base_dir, $test_dir);

  ## get dvm arguments ##
  my $dvm_args = $task->get_var('', 'dvm_args');
  #my @all_dvm_args = map $_ ? $_ : (), split /\r?\n\s*/m, $dvm_args;
  my @all_dvm_args = split /\r?\n\s*/m, $dvm_args;

  ## Enter output directory ##
  print "enter $work_dir\n";
  -e $work_dir || mkpath($work_dir);
  local $CWD = $work_dir;

  ## copy sources to work_dir ##
  for (0..$#src){
    copy($orig_src[$_], $src[$_])
      || print "can not copy file '$orig_src[$_]' to '$src[$_]'\n";
  }

  ## Execute dvm script ##
  for (@all_dvm_args){
    my $cmd = "$dvm $_";
    system($cmd) == 0 or die "failed: $cmd\n";
  }

  1
}

# $path = m_normalize_path($path);
# Converts slashes into current OS path delimiter.
sub m_normalize_path
{
  catfile(split m#/#, $_[0]);
}

1;
