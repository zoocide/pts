#!/usr/bin/perl
use strict;
use warnings;
use lib '..', '../external';
use Test::More tests => 47;
use File::Spec::Functions qw(catfile);
use File::Path qw(remove_tree);

BEGIN{ use_ok('Task') }

my $data_dir = 'data';

my $t = new_task('task_t_1');
# name, has_var, get_var
is($t->name, 'task_t_1');
ok($t->has_var('', 'name'));
is($t->get_var('', 'name'), 'task_t_1');
ok($t->has_var('', 'plugin'));
is($t->get_var('', 'plugin'), 'Simple1');
ok(!$t->has_var('', 'var'));
# set_index
$t->set_index(42);

# set_name
$t->set_name('xxx');
is($t->name, 'xxx');
is($t->get_var('', 'name'), 'task_t_1');
$t->reload_config;
is($t->name, 'xxx');
is($t->get_var('', 'name'), 'task_t_1');
#index
is($t->index, 42);

$t = new_task('task_t_2');
# name: set in config file
is($t->name, 'foo');
is($t->get_var('', 'name'), 'foo');

# get_var: variable not set
eval { $t->get_var('', 'var'); };
isnt(defined $@ ? "$@" : '', '');

my ($val, @val);
# get_var: default value
eval { $val = $t->get_var('', 'var', 'default'); };
is(defined $@ ? "$@" : '', '');
is($val, 'default');

# get_arr: variable not set
eval { $t->get_arr('', 'var'); };
isnt(defined $@ ? "$@" : '', '');

# get_arr: default value ()
eval { @val = $t->get_arr('', 'var', qw(a b c)); };
is(defined $@ ? "$@" : '', '');
is_deeply([@val], [qw(a b c)]);

# get_arr: default value []
eval { @val = $t->get_arr('', 'var', [qw(a b c)]); };
is(defined $@ ? "$@" : '', '');
is_deeply([@val], [qw(a b c)]);

$t = new_task('task_t_3');
# get_var: array
ok($t->has_var('q', 'var'));
is($t->get_var('q', 'var'), 'task_t_3 a b c');
# get_arr: array
eval { @val = $t->get_arr('q', 'var') };
is(defined $@ ? "$@" : '', '');
is_deeply([@val], [qw(task_t_3 a b c)]);

eval { test_data_dir() };
is(defined $@ ? "$@" : '', '');

-d $data_dir and remove_tree($data_dir);

sub new_task
{
  my $id = Task::ID->new(shift);
  my $name = $id->short_id;
  my $data_task_dir = catfile($data_dir, $name);
  my $t = Task->new($id, catfile('tasks', "$name.conf"), $data_task_dir);
  isa_ok($t, 'Task');
  is($t->task_dir, 'tasks');
  is($t->data_dir, $data_task_dir);
  $t
}

sub test_data_dir
{
  -d $data_dir and remove_tree($data_dir);

  my $t = new_task('task_t_3');
  my $d = $t->data_dir;
  $d eq catfile($data_dir, 'task_t_3') or die "wrong data_dir";
  eval { $t->make_data_dir };
  is(defined $@ ? "$@" : '', '');
  ok(-d $d);

  my $fname = catfile($d, 'file');
  open my $f, '>', $fname or die "cannot open file '$fname': $!";
  close $f;
  ok(-e $fname);
  eval { $t->clear_data_dir };
  is(defined $@ ? "$@" : '', '');
  ok(!-e $fname);

  $d = catfile($data_dir, 't');
  ok(!-e $d);
  eval { $t->make_data_dir($d) };
  is(defined $@ ? "$@" : '', '');
  ok(-d $d);
  $t->data_dir eq $d or die "wrong data_dir '".$t->data_dir."' after make_data_dir";

  -d $data_dir and remove_tree($data_dir);
}
