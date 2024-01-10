package Plugins::RunChild;
use strict;
use Plugins::Base;
use base qw(Plugins::Base);
use Exceptions;
use File::Spec::Functions qw(catfile);

sub process
{
  my ($class, $task) = @_;
  print_out("task '", $task->name, "' [$$] starts a child...\n");
  my $exe = catfile(qw(child bin child));
  dbg1 and dprint("`$exe`");
  `$exe`;
  $? == 0 or die "Child process failed\n";
  1
}

1;

