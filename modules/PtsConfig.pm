package PtsConfig;
use strict;
use FindBin;
use File::Spec::Functions qw(catfile);

my %c = (
  # tasks_dir => 'default_tasks_directory',
  # plugins_parent_dir => 'plugins_parent_direcotry', #It contains Plugins/all_plugins
);

sub tasks_dir {$c{tasks_dir} ||= catfile($FindBin::Bin, '..', 'tasks')}
sub plugins_parent_dir {$c{plugins_parent_dir} ||= catfile($FindBin::Bin, '..')}

1
