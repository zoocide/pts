#!/usr/bin/perl
use strict;
use warnings;
use lib '..';
use Test::More tests => 37;
use File::Temp qw(tempfile);

use Exceptions;

BEGIN{ use_ok('ConfigFile') }

my $fname = tempfile();

eval {
  my $conf;

  ## create new config file ##
  eval{ $conf = ConfigFile->new($fname) };
  ok(!$@, "create new ConfigFile");
  isa_ok($conf, 'ConfigFile');

  ## fill config file ##
  # check set_var, set_group
  eval {
    $conf->set_var('name', 'MyConf');
    $conf->set_var('plugin', 'Plugin');
    $conf->set_group('info');
    $conf->set_var('date', '21.12.2012');
    $conf->set_var('time', '13:42:59');
  };
  ok(!$@, 'set variables');

  ## check variables in config file ##
  # check get_var
  is($conf->get_var(''    , 'name'  ), 'MyConf'    );
  is($conf->get_var(''    , 'plugin'), 'Plugin'    );
  is($conf->get_var('info', 'date'  ), '21.12.2012');
  is($conf->get_var('info', 'time'  ), '13:42:59'  );
  ok(!defined $conf->get_var('group_not_existed', 'var_not_existed'));
  ok(!defined $conf->get_var('', 'var_not_existed'));

  # check is_set
  ok($conf->is_set(''    , 'name'  ));
  ok($conf->is_set(''    , 'plugin'));
  ok($conf->is_set('info', 'date'  ));
  ok($conf->is_set('info', 'time'  ));
  ok(!$conf->is_set('group_not_existed', 'var_not_existed'));
  ok(!$conf->is_set('', 'var_not_existed'));

  # check set_var_if_not_exists
  eval {
    $conf->set_group('info');
    $conf->set_var_if_not_exists('version', '0.1.0');
    $conf->set_var_if_not_exists('date', '01.01.2012');
  };
  ok(!$@, 'set variables if not exists');
  is($conf->get_var('info', 'date'   ), '21.12.2012');
  is($conf->get_var('info', 'version'), '0.1.0');

  # check file_name
  is($conf->file_name, $fname);

  ## save config file ##
  eval{ $conf->save };
  ok(!$@, 'config file saved');


  ## create new config file ##
  eval{ $conf = ConfigFile->new($fname) };
  ok(!$@, "create new ConfigFile");
  isa_ok($conf, 'ConfigFile');

  ## load config file from file ##
  eval{ $conf->load };
  ok(!$@, 'config file loaded');

  ## check content of the config file ##
  is($conf->get_var(''    , 'name'   ), 'MyConf'    );
  is($conf->get_var(''    , 'plugin' ), 'Plugin'    );
  is($conf->get_var('info', 'date'   ), '21.12.2012');
  is($conf->get_var('info', 'time'   ), '13:42:59'  );
  is($conf->get_var('info', 'version'), '0.1.0'     );
  ok(!defined $conf->get_var('group_not_existed', 'var_not_existed'));
  ok(!defined $conf->get_var('', 'var_not_existed'));
  # check is_set
  ok($conf->is_set(''    , 'name'  ));
  ok($conf->is_set(''    , 'plugin'));
  ok($conf->is_set('info', 'date'  ));
  ok($conf->is_set('info', 'time'  ));
  ok(!$conf->is_set('group_not_existed', 'var_not_existed'));
  ok(!$conf->is_set('', 'var_not_existed'));
};

## finally ##
unlink $fname if -e $fname;
throw if $@;

