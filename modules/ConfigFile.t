#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 20;
use File::Temp qw(tempfile);

use Exceptions;
use Exceptions::OpenFileError;

BEGIN{ use_ok('ConfigFile') }

my $fname = tempfile();

eval {
  my $conf;
  eval{ $conf = ConfigFile->new($fname) };
  ok(!$@, "create new ConfigFile");
  isa_ok($conf, 'ConfigFile');

  eval {
    $conf->set_var('name', 'MyConf');
    $conf->set_var('plugin', 'Plugin');
    $conf->set_group('info');
    $conf->set_var('date', '21.12.2012');
    $conf->set_var('time', '13:42:59');
  };
  ok(!$@, 'set variables');
  is($conf->get_var(''    , 'name'  ), 'MyConf'    );
  is($conf->get_var(''    , 'plugin'), 'Plugin'    );
  is($conf->get_var('info', 'date'  ), '21.12.2012');
  is($conf->get_var('info', 'time'  ), '13:42:59'  );
  ok(!defined $conf->get_var('group_not_existed', 'var_not_existed'), 'group_not_existed::var_not_existed not defined');
  ok(!defined $conf->get_var('', 'var_not_existed'), '::var_not_existed not defined');
  eval{ $conf->save };
  ok(!$@, 'config file saved');

  eval{ $conf = ConfigFile->new($fname) };
  ok(!$@, "create new ConfigFile");
  isa_ok($conf, 'ConfigFile');

  eval{ $conf->load };
  ok(!$@, 'config file loaded');

  is($conf->get_var(''    , 'name'  ), 'MyConf'    );
  is($conf->get_var(''    , 'plugin'), 'Plugin'    );
  is($conf->get_var('info', 'date'  ), '21.12.2012');
  is($conf->get_var('info', 'time'  ), '13:42:59'  );
  ok(!defined $conf->get_var('group_not_existed', 'var_not_existed'), 'group_not_existed::var_not_existed not defined');
  ok(!defined $conf->get_var('', 'var_not_existed'), '::var_not_existed not defined');
};

## finally ##
unlink $fname if -e $fname;
throw if $@;

