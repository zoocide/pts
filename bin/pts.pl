#!/bin/env perl
use strict;
#BEGIN { use Carp; $SIG{__WARN__} = sub {confess}; }
use constant windows => $^O eq 'MSWin32';
my $begin_time;
BEGIN{ eval{ require Time::HiRes; Time::HiRes->import('time') } }
BEGIN{ $begin_time = time; }
use FindBin;
use lib "$FindBin::RealBin/../modules";
use lib "$FindBin::RealBin/../modules/external";
our $VERSION;
BEGIN { $VERSION = v0.8.0; }
BEGIN{ *Task::dbg_level = sub () { 0 } }
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
use MyConsoleColors qw(color_str enable_colors);
use PtsColorScheme qw(color_ref);

our $script_start_time = time;

## load TaskDB ##
our $db;
try{ $db = TaskDB->new(PtsConfig->tasks_dir) } string2exception make_exlist
catch{ push @{$@}, Exceptions::Exception->new('can not load tasks database'); throw };

our $failed_fname;
our $num_procs;
our $debug = 0;
my $quiet;
my $config_fname = '.ptsconfig';

our ($clr_dbg, $clr_end, $clr_br_red, $clr_comment);
*clr_dbg = color_ref('dbg');
*clr_end = color_ref('end');
*clr_br_red = color_ref('br_red');
*clr_comment = color_ref('comment');

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
    colors => ['--color', 'Force to use colored output messages.', sub { enable_colors }],
    no_colors => ['--no-color', 'Do not use colored output messages.', sub { enable_colors(0) }],
  },
  groups => {
    OPTIONS => [qw(
      global quiet stat debug
      tasks_dir plugins_dir
      failed
      ttime
      force_mce no_mce
      num_procs
      colors no_colors
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
try {
  $args->parse_begin;
  $args->parse_part(\@ARGV);
  m_dprint_t($script_start_time - $begin_time, 'measured compilation time') if $debug >=2;
  m_dprint('args = ', join ', ', map "'$_'", @ARGV) if $debug >=2;
  m_dprint_t(time - $script_start_time, 'command line arguments parsed') if $debug >=2;
  load_config($config_fname, $args) if !$args->is_opt('global');
  $args->parse_end;
  MyConsoleColors->import(qw(clr_end clr_red clr_gray clr_green clr_bg_red));
  PtsColorScheme->import;
}
make_exlist
catch {
  for (@{$@}) {
    if (!ref($_)) {
      ${\$_} = color_str($_, $clr_br_red);
    }
    elsif (ref($_) eq 'Exceptions::Exception') {
      $_->init(color_str($_->msg, $clr_br_red));
    }
    elsif (ref($_) eq 'Exceptions::CmdArgsInfo' && @{$@} > 1) {
      $_->init(color_str($_->msg, $clr_comment));
    }
  }
  throw;
} 'List';

## list tasks ##
if ($args->use_case eq 'list'){
  my @list = $db->all_task_ids;
  @list = map {my $t = $db->get_task_light($_); $t->task_dir.": $_"} @list if $debug;
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

my $r = windows ? do_pts_main_with_worker() : do_pts_main();
m_dprint_t(time - $begin_time, 'measured overall time') if $debug >=2;
exit $r;


sub do_pts_main
{
  ## load module with constants enabled ##
  my $r = do 'pts-main.pm';
  die color_str("$@", $clr_br_red) if $@;
  die "could not do 'pts-main.pm': $!" if !defined $r;
  $r
}

sub do_pts_main_with_worker
{
  # In windows backticks commands hangs the SIGINT processing.
  # It will processed just after the command finishes.
  # The work around is to have a thread just for the reaction on signals.
  my $worker;
  if (!($worker = fork)) {
    exit do_pts_main();
  }

  require ProcessViewer;
  require POSIX;
  POSIX->import(qw(WNOHANG));

  ## set signal handlers ##
  our $terminated;
  my $old_sigint = $SIG{INT};
  $SIG{INT} = sub {
    &dbg1 and m_dprint("terminating on signal SIGINT");
    interrupt_workers($worker);

    ## kill all children processes ##
    kill_all_children_procs();
    STDERR->flush;

    ## restore the default handler ##
    $SIG{INT} = $old_sigint;
    $terminated = 1;
  };


  ## non-blocking wait ##
  m_sleep(0.0001) while waitpid($worker, WNOHANG()) == 0;
  $?
}

sub kill_all_children_procs
{
  for (ProcessViewer->new->update->children($$)) {
    my $child = $_->pid;
    next if waitpid $child, WNOHANG();
    &dbg1 and m_dprint(sprintf "killing %d %s\n", $child, $_->name);
    kill 'KILL', $child;
  }
}

sub interrupt_workers
{
  my ($worker) = @_;
  return if !defined $worker || waitpid $worker, WNOHANG();
  &dbg1 and m_dprint("terminate $worker worker");
  kill 'INT', $worker;
}

sub m_dprint
{
  print $clr_dbg."DEBUG: $_".$clr_end."\n" for split /\n/, join '', @_;
}

sub m_dprint_t
{
  my $t = sprintf '%.6f', shift;
  print $clr_dbg, "DEBUG [${t}s]: ", @_, $clr_end, "\n";
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

sub m_sleep
{
  select undef, undef, undef, $_[0]
}
