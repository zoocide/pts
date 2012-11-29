#!/usr/bin/perl
use strict;
use warnings;
use lib '..';
use Exceptions;

use Test::More tests => 97;
BEGIN{ use_ok('ConfigFileScheme'); }

sub nothrow_ok (&$)
{
  eval{ &{$_[0]} };
  ok(!$@, $_[1]);
}

sub throw_ok (&$)
{
  eval{ &{$_[0]} };
  ok($@, $_[1]);
}

my $section_name = '';
my $sch;
try {

  $section_name = 'S1';
  ok($sch = ConfigFileScheme->new(
    required => {'' => [qw(name plugin)]},
  ), 'creating new scheme');
  isa_ok($sch, 'ConfigFileScheme');

  ok_is_not_('multiline', $sch, '', 'not_existsed_var');
  ok_is_not_('multiline', $sch, 'not_existed_group', 'name');
  ok_is_not_('multiline', $sch, '', 'name');

  ok_is_not_('join_lines', $sch, '', 'not_existsed_var');
  ok_is_not_('join_lines', $sch, 'not_existed_group', 'name');
  ok_is_not_('join_lines', $sch, '', 'name');

  ok_is_    ('valid', $sch, '', 'not_existsed_var');
  ok_is_    ('valid', $sch, 'not_existed_group', 'name');
  ok_is_    ('valid', $sch, '', 'name');


  $section_name = 'S2';
  ok($sch = ConfigFileScheme->new(
  ), 'creating new empty scheme');
  isa_ok($sch, 'ConfigFileScheme');

  ok_is_not_('multiline', $sch, '', 'not_existed_var');
  ok_is_not_('multiline', $sch, 'not_existed_group', 'name');

  ok_is_not_('join_lines', $sch, '', 'not_existed_var');
  ok_is_not_('join_lines', $sch, 'not_existed_group', 'name');

  ok_is_    ('valid', $sch, '', 'not_existsed_var');
  ok_is_    ('valid', $sch, 'not_existed_group', 'name');
  ok_is_    ('valid', $sch, '', 'name');


  $section_name = 'S3';
  ok($sch = ConfigFileScheme->new(
    multiline => {
      ''   => [qw(name)],
      'gr' => [qw(var_42 var_43 var_44)],
    },
  ), 'creating new scheme');
  isa_ok($sch, 'ConfigFileScheme');

  ok_is_not_('multiline', $sch, '', 'not_existed_var');
  ok_is_not_('multiline', $sch, 'not_existed_group', 'name');
  ok_is_    ('multiline', $sch, '', 'name');
  ok_is_    ('multiline', $sch, 'gr', 'var_42');

  ok_is_not_('join_lines', $sch, '', 'not_existed_var');
  ok_is_not_('join_lines', $sch, 'not_existed_group', 'name');
  ok_is_not_('join_lines', $sch, '', 'name');
  ok_is_not_('join_lines', $sch, 'gr', 'var_42');

  ok_is_    ('valid', $sch, '', 'not_existsed_var');
  ok_is_    ('valid', $sch, 'not_existed_group', 'name');
  ok_is_    ('valid', $sch, '', 'name');
  ok_is_not_('join_lines', $sch, 'gr', 'var_42');

  $section_name = 'S4';
  ok($sch = ConfigFileScheme->new(
    strict => 1,
    multiline => {
      'arrays'     => 1,
      'long_lines' => 1,
      'data'       => 1,
      'options'    => [qw(mlines jlines)],
    },
    join_lines => {
      'long_lines' => 1,
      'data'       => 1,
      'options'    => [qw(jlines)],
    },
    required => {
      '' => [qw(name plugin)],
      'info' => 1,
      'arrays' => [qw(files)],
    },
    struct => {
      ''           => [qw(name type plugin)],
      'data'       => 1,
      'arrays'     => [qw(files words)],
      'long_lines' => [qw(mlines)],
      'options'    => [qw(mlines jlines sline)],
      'info'       => [qw(date time)],
    },
  ), 'creating new scheme');
  isa_ok($sch, 'ConfigFileScheme');

  ok_is_not_('multiline', $sch, ''          , 'not_existed_var');
  ok_is_    ('multiline', $sch, 'data'      , 'not_existed_var');
  ok_is_    ('multiline', $sch, 'arrays'    , 'not_existed_var');
  ok_is_    ('multiline', $sch, 'long_lines', 'not_existed_var');
  ok_is_not_('multiline', $sch, 'options'   , 'not_existed_var');
  ok_is_not_('multiline', $sch, 'info'      , 'not_existed_var');
  ok_is_not_('multiline', $sch, 'not_existed_group', 'name');
  ok_is_not_('multiline', $sch, 'not_existed_group', 'mlines');
  ok_is_not_('multiline', $sch, '', 'name');
  ok_is_not_('multiline', $sch, '', 'type');
  ok_is_not_('multiline', $sch, '', 'plugin');
  ok_is_    ('multiline', $sch, 'arrays', 'files');
  ok_is_    ('multiline', $sch, 'arrays', 'words');
  ok_is_    ('multiline', $sch, 'long_lines', 'mlines');
  ok_is_    ('multiline', $sch, 'options', 'mlines');
  ok_is_    ('multiline', $sch, 'options', 'jlines');
  ok_is_not_('multiline', $sch, 'options', 'sline');
  ok_is_not_('multiline', $sch, 'info', 'date');
  ok_is_not_('multiline', $sch, 'info', 'time');

  ok_is_not_('join_lines', $sch, ''          , 'not_existed_var');
  ok_is_    ('join_lines', $sch, 'data'      , 'not_existed_var');
  ok_is_not_('join_lines', $sch, 'arrays'    , 'not_existed_var');
  ok_is_    ('join_lines', $sch, 'long_lines', 'not_existed_var');
  ok_is_not_('join_lines', $sch, 'options'   , 'not_existed_var');
  ok_is_not_('join_lines', $sch, 'info'      , 'not_existed_var');
  ok_is_not_('join_lines', $sch, 'not_existed_group', 'name');
  ok_is_not_('join_lines', $sch, 'not_existed_group', 'mlines');
  ok_is_not_('join_lines', $sch, '', 'name');
  ok_is_not_('join_lines', $sch, '', 'type');
  ok_is_not_('join_lines', $sch, '', 'plugin');
  ok_is_not_('join_lines', $sch, 'arrays', 'files');
  ok_is_not_('join_lines', $sch, 'arrays', 'words');
  ok_is_    ('join_lines', $sch, 'long_lines', 'mlines');
  ok_is_not_('join_lines', $sch, 'options', 'mlines');
  ok_is_    ('join_lines', $sch, 'options', 'jlines');
  ok_is_not_('join_lines', $sch, 'options', 'sline');
  ok_is_not_('join_lines', $sch, 'info', 'date');
  ok_is_not_('join_lines', $sch, 'info', 'time');

  ok_is_not_('valid', $sch, ''          , 'not_existed_var');
  ok_is_    ('valid', $sch, 'data'      , 'not_existed_var');
  ok_is_not_('valid', $sch, 'arrays'    , 'not_existed_var');
  ok_is_not_('valid', $sch, 'long_lines', 'not_existed_var');
  ok_is_not_('valid', $sch, 'options'   , 'not_existed_var');
  ok_is_not_('valid', $sch, 'info'      , 'not_existed_var');
  ok_is_not_('valid', $sch, 'not_existed_group', 'name');
  ok_is_not_('valid', $sch, 'not_existed_group', 'mlines');
  ok_is_    ('valid', $sch, '', 'name');
  ok_is_    ('valid', $sch, '', 'type');
  ok_is_    ('valid', $sch, '', 'plugin');
  ok_is_    ('valid', $sch, 'arrays', 'files');
  ok_is_    ('valid', $sch, 'arrays', 'words');
  ok_is_    ('valid', $sch, 'long_lines', 'mlines');
  ok_is_    ('valid', $sch, 'options', 'mlines');
  ok_is_    ('valid', $sch, 'options', 'jlines');
  ok_is_    ('valid', $sch, 'options', 'sline');
  ok_is_    ('valid', $sch, 'info', 'date');
  ok_is_    ('valid', $sch, 'info', 'time');

  my $conf_base = {
    ''           => {
      name => 'my name',
      type => 'Type',
      plugin => 'Plugin'
    },
    'data'       => {
      var_42 => ['line_1', 'line_2'],
      var_91 => 'value',
    },
    'arrays'     => {
      files => ['file1', 'file2'],
      words => [],
    },
    'long_lines' => {
      mlines => "line1\nline2",
    },
    'options'    => {
      mlines => ['line1', 'line2'],
      jlines => "line1\nline2",
      sline  => 'line',
    },
    'info'       => {
      date => '21.12.2012',
      time => 123456,
    },
  };
  my $conf = clone($conf_base);

  nothrow_ok { $sch->check_required($conf) } 'requirements are satisfied';

  delete $conf->{info}{date};
  throw_ok { $sch->check_required($conf) } 'requirements are not satisfied';

  $conf = clone($conf_base);
  delete $conf->{''}{type};
  nothrow_ok { $sch->check_required($conf) } 'requirements are satisfied';
}
exception2string;

sub ok_is_
{
  my ($type, $scheme, $gr, $var) = @_;
  ok(eval "\$scheme->is_$type(\$gr,\$var)" && !$@, $section_name.": ${gr}::$var is $type");
}

sub ok_is_not_
{
  my ($type, $scheme, $gr, $var) = @_;
  ok(eval "!\$scheme->is_$type(\$gr,\$var)" && !$@, $section_name.": ${gr}::$var is not $type");
}

sub clone
{
  ! ref $_[0]            ? $_[0]
  : ref $_[0] eq 'ARRAY' ? [map clone($_), @{$_[0]}]
  : ref $_[0] eq 'HASH'  ? {map +($_, clone($_[0]{$_})), keys %{$_[0]}}
  : die "can not clone object\n";
}

