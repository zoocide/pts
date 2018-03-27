package PtsConfig;
use strict;
use FindBin;
use File::Spec::Functions qw(catfile);

my %c = (
  # tasks_dir => 'default_tasks_directory',
  # plugins_parent_dirs => ['plugins_parent_direcotry',...], #It contains Plugins/all_plugins
  plugins_parent_dirs => [catfile($FindBin::Bin, '..')],
);

sub tasks_dir {$c{tasks_dir} ||= catfile($FindBin::Bin, '..', 'tasks')}
sub plugins_parent_dirs {@{$c{plugins_parent_dirs}}}
# PtsConfig->add_plugins_parent_dir($dir);
sub add_plugins_parent_dir { push @{$c{plugins_parent_dirs}}, $_[1] }

1
