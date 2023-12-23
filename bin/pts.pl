#!/bin/env perl
use strict;
#BEGIN { use Carp; $SIG{__WARN__} = sub {confess}; }
my $begin_time;
BEGIN{ eval{ require Time::HiRes; Time::HiRes->import('time') } }
BEGIN{ $begin_time = time; }
use FindBin;
use lib "$FindBin::RealBin/../modules";
use lib "$FindBin::RealBin/../modules/external";
our $VERSION;
BEGIN { $VERSION = v0.7.2; }
BEGIN{ *Task::dbg_level = sub () { 0 } }
BEGIN{ *TaskDB::dbg_level = sub () { 0 } }
use PtsConfig;
use CmdArgs;
use CmdArgs::BasicTypes;
use Cwd;
use Exceptions;
use Exceptions::OpenFileError;
use Exceptions::TextFileError;
use TaskDB;
use File::Basename qw(dirname);
use File::Spec::Functions qw(splitpath catpath splitdir catdir catfile);

BEGIN{
  my $v = -t STDOUT && ($^O ne 'MSWin32' || eval{ require Win32::Console::ANSI });
  *use_colors = sub () { $v }
}
use constant {
  clr_end    => use_colors ? "\e[m" : '',
  clr_black  => use_colors ? "\e[30m" : '',
  clr_red    => use_colors ? "\e[31m" : '',
  clr_green  => use_colors ? "\e[32m" : '',
  clr_yellow => use_colors ? "\e[33m" : '',
  clr_blue   => use_colors ? "\e[34m" : '',
  clr_magenta=> use_colors ? "\e[35m" : '',
  clr_cyan   => use_colors ? "\e[36m" : '',
  clr_white  => use_colors ? "\e[37m" : '',
  clr_bg_black  => use_colors ? "\e[40m" : '',
  clr_bg_red    => use_colors ? "\e[41m" : '',
  clr_bg_green  => use_colors ? "\e[42m" : '',
  clr_bg_yellow => use_colors ? "\e[43m" : '',
  clr_bg_blue   => use_colors ? "\e[44m" : '',
  clr_bg_magenta=> use_colors ? "\e[45m" : '',
  clr_bg_cyan   => use_colors ? "\e[46m" : '',
  clr_bg_white  => use_colors ? "\e[47m" : '',
  clr_gray      => use_colors ? "\e[90m" : '',
  clr_br_red    => use_colors ? "\e[91m" : '',
  clr_br_green  => use_colors ? "\e[92m" : '',
  clr_br_yellow => use_colors ? "\e[93m" : '',
  clr_br_blue   => use_colors ? "\e[94m" : '',
  clr_br_magenta=> use_colors ? "\e[95m" : '',
  clr_br_cyan   => use_colors ? "\e[96m" : '',
  clr_br_white  => use_colors ? "\e[97m" : '',
};
use constant {
  clr_dbg => clr_cyan,
};

our $script_start_time = time;

## load TaskDB ##
our $db;
try{ $db = TaskDB->new(PtsConfig->tasks_dir) } string2exception make_exlist
catch{ push @{$@}, Exceptions::Exception->new('can not load tasks database'); throw };

our $failed_fname;
our $num_procs;
my $debug = 0;
my $quiet;
my $config_fname = '.ptsconfig';

our $args = CmdArgs->declare(
  sprintf('%vd',$VERSION),
  options => {
    tasks_dir => ['-T:Dir<<tasks_dir>>', 'Allow to process tasks from <tasks_dir>.'
                  .' It extends the tasks database with tasks from this directory.',
                  sub{ $db->add_tasks_dir($_) }],
    quiet => ['-q --quiet', 'Do not print statistics and task name.', \$quiet],
    debug => ['-D --debug', 'Print debug information. -DD produces even more information.', sub { $debug++ }],
    list  => ['-l --list',  'Print all tasks in database.'],
    stat  => ['-s --stat',  'Force to print statistics even for one task.'],
    global => ['-g', "Do not load local $config_fname. Use global configuration."],
    plugins_dir => ['-I:Dir<<plugins_dir>>', 'Include plugins from directory.',
                    sub{ PtsConfig->add_plugins_parent_dir($_) }],
    failed  => ['--failed:<<file>>', 'Put failed tasks into <file>.',
                sub { $failed_fname = $_ }],
    ttime => ['--total-time', 'Print total time.'],
    force_mce => ['--mce', 'Force to use MCE parallel engine. It should be installed from CPAN.'],
    no_mce => ['--no-mce', "Don't use MCE parallel engine."],
    num_procs => ['--np:Int', 'Set the number of parallel workers. It makes sense only for the MCE engine.', \$num_procs],
  },
  groups => {
    OPTIONS => [qw(
      global quiet stat debug
      tasks_dir plugins_dir
      failed
      ttime
      force_mce no_mce
      num_procs
    )],
  },
  use_cases => {
    main => ['~OPTIONS taskset...', 'Process a set of tasks.'
             .' There is a tasks database, from which you can select tasks to execute.'
             .' Also you can sepcify files, containing tasks names.'],
    list => ['~OPTIONS list', 'Print all tasks in database.'],
  },
  restrictions => [
    'force_mce|no_mce',
  ],
);
$args->parse_begin;
$args->parse_part(\@ARGV);
m_dprint_t($script_start_time - $begin_time, 'measured compilation time') if $debug >=2;
m_dprint('args = ', join ', ', map "'$_'", @ARGV) if $debug >=2;
m_dprint_t(time - $script_start_time, 'command line arguments parsed') if $debug >=2;
load_config($config_fname, $args) if !$args->is_opt('global');
$args->parse_end;

## list tasks ##
if ($args->use_case eq 'list'){
  my @list = $db->all_task_ids;
  @list = map {my $t = $db->get_task($_); $t->task_dir.": $_"} @list if $debug;
  print $_, "\n" for sort @list;
  exit 0;
}

## check arguments ##
defined $num_procs && $num_procs <= 0 and die "the number of workers should be a positive integer\n";

## set constants ##
{my $d = $debug >= 1; *{dbg1} = sub () { $d } }
{my $d = $debug >= 2; *{dbg2} = sub () { $d } }
{my $q = $quiet; *{quiet} = sub () { $q } }
{my $v = $args->is_opt('force_mce'); *{force_mce} = sub () { $v } }
{my $v = $args->is_opt('no_mce'); *{no_mce} = sub () { $v } }

## load module with constants enabled ##
my $r = do 'pts-main.pm';
die $@ if $@;
die "could not do 'pts-main.pm': $!" if !defined $r;
m_dprint_t(time - $begin_time, 'measured overall time') if $debug >=2;
$r;


sub m_dprint
{
  print clr_dbg."DEBUG: $_".clr_end."\n" for split /\n/, join '', @_;
}

sub m_dprint_t
{
  my $t = sprintf '%.6f', shift;
  print clr_dbg, "DEBUG [${t}s]: ", @_, clr_end, "\n";
}

sub load_config
{
  my $fname = shift;
  my $args = shift;

  my $config_path = find_config_path($fname) or return;
  m_dprint("read configuration from '$config_path'") if $debug >=1;
  my $time = time if $debug >=2;
  my $config_dir = dirname($config_path);
  my $cf = ConfigFile->new($config_path, {
    struct => {'pts' => [qw(options)]},
    #strict => {'pts' => 1},
  });
  $cf->set('', 'PTS_CONFIG_DIR', $config_dir);
  $cf->load;
  my @pts_opts = $cf->get_arr('pts', 'options');
  m_dprint('pts::options = ', join ', ', map "'$_'", @pts_opts) if $debug >=2;
  $args->parse_part(\@pts_opts);
  m_dprint_t(time - $time, 'configuration loaded') if $debug >=2;
}

sub find_config_path
{
  my $fname = shift;
  my $path = catfile(cwd(), $fname);
  m_dprint("check path '$path'") if $debug >=2;
  return $path if -e $path;
  my ($drive, $dirs) = splitpath($path);
  my @dirs = splitdir($dirs); # '/d/i/r/s/' => ('', 'd', 'i', 'r', 's', '');
  pop @dirs; # remove the last empty dir;
  pop @dirs; # remove the first parent already checked.
  while (@dirs) {
    $path = catpath($drive, catdir(@dirs), $fname);
    m_dprint("check path '$path'") if $debug >=2;
    return $path if -e $path;
    pop @dirs;
  }
  undef
}
