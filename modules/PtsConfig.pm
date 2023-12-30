package PtsConfig;
use strict;
use FindBin;
use File::Spec::Functions qw(catfile);

my %c = (
  sys_dir => catfile($FindBin::RealBin, '..'),
  # tasks_dir => 'default_tasks_directory',
  # plugins_parent_dirs => ['plugins_parent_direcotry',...], #It contains Plugins/all_plugins
  plugins_parent_dirs => [catfile($FindBin::RealBin, '..')],
);

sub tasks_dir {$c{tasks_dir} ||= catfile($c{sys_dir}, 'tasks')}
sub plugins_parent_dirs {@{$c{plugins_parent_dirs}}}
# PtsConfig->add_plugins_parent_dir($dir);
sub add_plugins_parent_dir { push @{$c{plugins_parent_dirs}}, catfile($_[1]) }
sub doc_dir { catfile($c{sys_dir}, 'doc') }
sub sys_dir { $c{sys_dir} }

1
