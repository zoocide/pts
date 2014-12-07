package PtsConfig;
use strict;
use FindBin;
use File::Spec::Functions qw(catfile);

my %c;

sub tasks_dir {$c{tasks_dir} |= catfile($FindBin::Bin, '..', 'tasks')}
sub plugins_parent_dir {$c{plugins_parent_dir}|=catfile($FindBin::Bin, '..')}

1
