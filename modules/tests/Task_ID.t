#!/usr/bin/perl
use strict;
use warnings;
use lib '..', '../external';
use Test::More tests => 63;
use File::Temp qw(tempfile);

#use constant "Task::ID::legacy" => 1;
BEGIN{ use_ok('Task::ID') }

## base checks: task name, simple arguments, list arguments ##
my $id = Task::ID->new('task');
isa_ok($id, 'Task::ID');
is($id->short_id, 'task');
is($id->basename, 'task');
is_deeply([$id->dirs], []);
is($id->id, 'task');
is_deeply({$id->args}, {});
eval { $id->reset('test : arg1 = v, ::arg2 = a b, gr::arg3 = "hello world" ') };
is (defined $@ ? "$@" : '', '');
is($id->short_id, 'test');
is($id->basename, 'test');
is_deeply([$id->dirs], []);
is("$id", $id->id);
is($id->id, 'test:::arg1=v,::arg2=a b,gr::arg3=hello\ world');
is($id->args_str, '::arg1=v,::arg2=a b,gr::arg3=hello\ world');
is_deeply({$id->args}, {
  '' => {
    arg1 => ['v'],
    arg2 => [qw(a b)],
  },
  gr => {
    arg3 => ['hello world'],
  },
});

## check special symbols in argument value ##
eval {
$id->reset(q( task : a1 = a'bc' "d e f"${foo}, a2 = '\n\t'\' "\n\t", a3 =)."'abc\ndef\n'")
};
is (defined $@ ? "$@" : '', '');
is($id->short_id, 'task');
is($id->basename, 'task');
is_deeply([$id->dirs], []);
is($id->id, qq(task:::a1=abc d\\ e\\ f\\\${foo},::a2=\\\\n\\\\t\\' \\n\\t,::a3=abc\\ndef\\n));
is($id->args_str, qq(::a1=abc d\\ e\\ f\\\${foo},::a2=\\\\n\\\\t\\' \\n\\t,::a3=abc\\ndef\\n));
is_deeply({$id->args}, {
  '' => {
    a1 => ['abc', 'd e f${foo}'],
    a2 => ['\n\t\'', "\n\t"],
    a3 => ["abc\ndef\n"],
  },
});

## check reset to itself ##
eval { $id->reset($id->id) };
is (defined $@ ? "$@" : '', '');
is($id->short_id, 'task');
is($id->basename, 'task');
is_deeply([$id->dirs], []);
is("$id", $id->id);
is($id->id, qq(task:::a1=abc d\\ e\\ f\\\${foo},::a2=\\\\n\\\\t\\' \\n\\t,::a3=abc\\ndef\\n));
is($id->args_str, qq(::a1=abc d\\ e\\ f\\\${foo},::a2=\\\\n\\\\t\\' \\n\\t,::a3=abc\\ndef\\n));
is_deeply({$id->args}, {
  '' => {
    a1 => ['abc', 'd e f${foo}'],
    a2 => ['\n\t\'', "\n\t"],
    a3 => ["abc\ndef\n"],
  },
});

## check empty variable ##
eval { $id->reset('t:a= ,v=') };
is (defined $@ ? "$@" : '', '');
is($id->short_id, 't');
is($id->basename, 't');
is_deeply([$id->dirs], []);
is("$id", $id->id);
is($id->id, 't:::a=,::v=');
is($id->args_str, '::a=,::v=');
is_deeply({$id->args}, {
  '' => {
    a => [],
    v => [],
  },
});

## check file path ##
eval { $id->reset('a/path/t:a= ,v=') };
is (defined $@ ? "$@" : '', '');
is($id->short_id, 'a/path/t');
is($id->basename, 't');
is_deeply([$id->dirs], [qw(a path)]);
is("$id", $id->id);
is($id->id, 'a/path/t:::a=,::v=');

## check agr2str ##
is(Task::ID::arg2str('' , a => ), '::a=');
is(Task::ID::arg2str('g', b => ), 'g::b=');
is(Task::ID::arg2str(undef, b => ), 'b=');
is(Task::ID::arg2str(), '');
is(Task::ID::arg2str(undef, undef, qw(a b)), 'a b');
is(Task::ID::arg2str('' , arg1 => 'v'), '::arg1=v');
is(Task::ID::arg2str('_', arg2 => qw(a b)), '_::arg2=a b');
is(Task::ID::arg2str('gr',arg3 => 'hello world'), 'gr::arg3=hello\ world');
is(Task::ID::arg2str('' , a1 => 'abc', 'd e f${foo}'), qq(::a1=abc d\\ e\\ f\\\${foo}));
is(Task::ID::arg2str('' , a2 => '\n\t\'', "\n\t"), qq(::a2=\\\\n\\\\t\\' \\n\\t));
is(Task::ID::arg2str('' , a3 => "abc\ndef\n"), qq(::a3=abc\\ndef\\n));

## check 'task:var,var1' as a shorthand for 'task:var=1,var1=1' ##
eval { $id->reset('t:a') };
is (defined $@ ? "$@" : '', '');
is($id->short_id, 't');
is($id->id, 't:::a=1');
is_deeply({$id->args}, {
  '' => {
    a => ['1'],
  },
});
eval { $id->reset('t:init,b=1 2,c') };
is (defined $@ ? "$@" : '', '');
is($id->short_id, 't');
is($id->id, 't:::b=1 2,::c=1,::init=1');
is_deeply({$id->args}, {
  '' => {
    init => [1],
    b => [1, 2],
    c => [1],
  },
});
