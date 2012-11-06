#!/usr/bin/perl -w
use strict;
use lib '../modules';
use CmdArgs;

{package CmdArgs::Types::Filename; sub check{ -f $_[1] } }
{package CmdArgs::Types::Dir;      sub check{ -d $_[1] } }

my $args = CmdArgs->declare(
  '0.1',
  options => {
    org  => ['-o --org', 'descr...'],
    sil  => ['-s --silent', 'silent mode'],
    file => ['-f:Filename --filename', 'specify filename'],
    dir  => ['-d:Dir --dest', 'specify destination directory'],
  },
  use_cases => { prime => ['OPTIONS arg1', ''] },
);
$args->parse;

print "everything is ok ;)\n";

use Data::Dumper;
print Dumper($args);

__END__
my $args2 = CmdArgs->new(
  '0.1',
  opts => { cp    => CmdArgs::Flag(['-c', 'cp'], 'copy files'),
            mv    => CmdArgs::Flag(['-m', 'mv'], 'move files'),
            files => CmdArgs::Args('FILE', 'files'),
          },
  use_cases => { main => ['OPTIONS files', 'do something with files'] },
);

my $args = CmdArgs->new(
  '0.1',
  use_cases => { main => ['file_1 file_2', 'do something with files' },
);
