#!/usr/bin/perl -w
use strict;
use v5.10;
use File::Path qw(make_path);

my $cmake = 'cmake';
my $work_dir = 'build';

make_path($work_dir);
make_path('bin');
chdir $work_dir or die "can not change directory to $work_dir: $!\n";
system($cmake, '-DCMAKE_INSTALL_PREFIX=..', '..') == 0 or die "configuration failed: $!\n";
system($cmake, '--build', '.', '--config=Release') == 0 or die "build failed: $!\n";
system($cmake, '--install', '.') == 0 or die "install failed: $!\n";
