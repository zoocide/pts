#!/usr/bin/perl
use strict;
use warnings;
use lib '..', '../external';
use Test::More tests => 28;
use File::Temp qw(tempfile);

BEGIN{ use_ok('Task') }

## base checks: task name, simple arguments, list arguments ##
my $id = Task::ID->new('task');
isa_ok($id, 'Task::ID');
is($id->short_id, 'task');
is($id->id, 'task');
is_deeply({$id->args}, {});
eval { $id->reset('test : arg1 = v, ::arg2 = a b, gr::arg3 = "hello world" ') };
is (defined $@ ? "$@" : '', '');
is($id->short_id, 'test');
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
is("$id", $id->id);
is($id->id, 't:::a=,::v=');
is($id->args_str, '::a=,::v=');
is_deeply({$id->args}, {
  '' => {
    a => [],
    v => [],
  },
});
