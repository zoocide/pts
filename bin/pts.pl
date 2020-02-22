#!/usr/bin/perl -w
use strict;
use threads;
use FindBin;
use lib "$FindBin::Bin/../modules";
use lib "$FindBin::Bin/../modules/external";
use PtsConfig;
use CmdArgs;
use CmdArgs::BasicTypes;
use Exceptions;
use Exceptions::OpenFileError;
use Exceptions::TextFileError;
use TaskDB;
use File::Spec::Functions qw(catfile);
use TasksOutput;

BEGIN{ eval{ require 'Time/HiRes.pm'; Time::HiRes->import('time') } }

our $VERSION = v0.4.1;

use constant {
  dbg1 => 1,
  dbg2 => 0,
};

my $script_start_time = time;

## load TaskDB ##
my $db;
try{ $db = TaskDB->new(PtsConfig->tasks_dir) } string2exception make_exlist
catch{ push @{$@}, Exceptions::Exception->new('can not load tasks database'); throw };

my $failed_fname;
my $debug;
my $quiet;

my $args = CmdArgs->declare(
  sprintf('%vd',$VERSION),
  options => {
    tasks_dir => ['-T:Dir<<tasks_dir>>', 'Allow to process tasks from <tasks_dir>.'
                  .' It extends the tasks database with tasks from this directory.',
                  sub{ $db->add_tasks_dir($_) }],
    quiet => ['-q --quiet', 'Do not print statistics and task name.', \$quiet],
    debug => ['-D --debug', 'Print debug information.', \$debug],
    list  => ['-l --list',  'Print all tasks in database.'],
    stat  => ['-s --stat',  'Force to print statistics even for one task.'],
    plugins_dir => ['-I:Dir<<plugins_dir>>', 'Include plugins from directory.',
                    sub{ PtsConfig->add_plugins_parent_dir($_) }],
    failed  => ['--failed:<<file>>', 'Put failed tasks into <file>.',
                sub { $failed_fname = $_ }],
    ttime => ['--total-time', 'Print total time.'],
  },
  groups => {
    OPTIONS => [qw(quiet stat debug tasks_dir plugins_dir failed ttime)],
  },
  use_cases => {
    main => ['OPTIONS taskset...', 'Process a set of tasks.'
             .' There is a tasks database, from which you can select tasks to execute.'
             .' Also you can sepcify files, containing tasks names.'],
    list => ['OPTIONS list', 'Print all tasks in database.'],
  },
);
$args->parse;

## list tasks ##
if ($args->use_case eq 'list'){
  my @list = $db->all_task_ids;
  @list = map {my $t = $db->get_task($_); $t->task_dir.": $_"} @list if $debug;
  print $_, "\n" for sort @list;
  exit 0;
}

## obtain tasks to execute ##
my @tasks = map { -f $_ ? load_task_set($db, $_) : $db->new_task($_) }
                @{$args->arg('taskset')};

## open file $failed_fname ##
my $failed_file;
if ($failed_fname){
  open $failed_file, '>', $failed_fname
      or die "Can not write to file '$failed_fname': $!\n";
}

my $start_time = 0;
$start_time = time if $debug;

## load plugins ##
load_plugins(@tasks);

## construct task sequence ##
my $prepared = prepare_tasks(@tasks);
dbg1 and dprint_tasks($prepared);

## process tasks ##
my ($all, $failed, $skipped) = process_tasks($prepared);

## print statistics ##

dbg1 and debug(sprintf "tasks time = %.3f", time - $start_time);
printf "total time = %.3f\n", time - $script_start_time if $args->is_opt('ttime');

my $num_total  = @$all;
my $num_failed = @$failed;
my $num_skipped = @$skipped;
my $num_ok     = $num_total - ($num_failed + $num_skipped);

print "\nstatistics:"
     ,"\nnum total    = ", $num_total
     ,"\nnum complete = ", $num_ok
     ,"\nnum skipped  = ", $num_skipped
     ,"\nnum failed   = ", $num_failed
     ,"\n"
     if $args->is_opt('stat') || (!$quiet && @$all > 1);

## write failed tasks ##
if (@$failed){
  if ($failed_fname){
    print $failed_file $_->id."\n" for @$failed;
    close $failed_file;
    debug("Failed tasks were written to file '$failed_fname'.\n");
  }
  exit 1
}

## remove failed file on success ##
if ($failed_file){
  close $failed_file;
  unlink $failed_fname;
}

##### END #####

sub debug
{
  return if !$debug;
  print "DEBUG: $_\n" for split /\n/, join '', @_;
}

sub load_task_set
{
  my ($db, $fname) = @_;
  debug("load task set from file $fname");
  my @ret;
  open(my $f, '<', $fname) || throw OpenFileError => $fname;
  ### rules ###
  #1)  # comment
  #2)  \#name  => '#name'
  #3)  \\#name => '\#name'
  my $s;
  for (my $ln = 1; defined ($s = <$f>); $ln++) {
    # remove spaces at the beginnig, and comments.
    chomp $s;
    $s =~ s/^\s*(?:#.*)?//;
    next if !$s;
    try { push @ret, $db->new_task($s) }
    catch { throw TextFileError => $fname, $ln, $@ };
  }
  close $f;
  debug("$fname: loaded tasks:\n", map('  '.$_->id."\n", @ret));
  @ret
}

sub load_plugins
{
  my @tasks = @_;
  for my $plugins_pdir (PtsConfig->plugins_parent_dirs) {
    eval "use lib '$plugins_pdir'";
    die $@ if $@;
    debug('plugins dir = '.catfile($plugins_pdir, 'Plugins'));
  }

  my @failed;
  my %plugins;
  for my $task (@tasks){
    my $pname = $task->plugin;
    next if exists $plugins{$pname};
    debug("load plugin $pname");
    (my $req_pname = $pname) =~ s#::#/#g;
    eval {
      no strict 'refs';
      my $d = $debug;
      *{"Plugins::${pname}::dbg1"} = sub () { $d };
      require "Plugins/$req_pname.pm"
    };
    if ($@){
      print $@;
      push @failed, $pname;
    }
    $plugins{$pname} = !$@;
    if (dbg2) {
      use B::Deparse;
      my $d = B::Deparse->new();
      print $d->coderef2text(\&{"Plugins::${pname}::process"}), "\n";
    }
  }
  @failed and die "ERROR! Can not load plugins: ".join(', ', @failed)."\n";
}

sub index_tasks
{
  my $tasks = shift;
  my $i = shift || 0;
  for my $t (@$tasks) {
    if (ref $t eq 'ARRAY') {
      $i = index_tasks($_, $i) for @$t;
      next;
    }
    $t->set_index($i++);
  }
  $i
}

sub prepare_tasks
{
  my @ret;
  for (my $i = 0; $i < @_; $i++) {
    my $t = $_[$i];
    my $class = 'Plugins::'.$t->plugin;
    if ($class->can('on_prepare')) {
      $class->on_prepare($t, $i, \@_, \@ret, $db);
      next;
    }
    push @ret, $t;
  }
  index_tasks(\@ret);
  \@ret
}

sub dprint_tasks
{
  my ($tasks, $pref) = @_;
  $pref = '' if !defined $pref;
  debug($pref, '[');
  for my $t (@$tasks) {
    if (ref $t eq 'ARRAY') {
      debug($pref.'  ## start parallel section ##');
      dprint_tasks($_, $pref.'  ') for @$t;
      debug($pref.'  ## end parallel section ##');
      next;
    }
    debug($pref.'  ', $t->index, ':', $t->id);
  }
  debug($pref, ']');
}

sub format_msg
{
  join '', map "# $_\n", split /\n/, join '', @_
}

sub m_sleep
{
  select undef, undef, undef, $_[0]
}

sub process_tasks
{
  my $tasks = shift;
  my $output : shared = shift || TasksOutput->new;
  my $is_master = $output->is_main_thread;

  my @all;
  my @failed;
  my @skipped;

  for my $task (@$tasks) {
    if (ref $task eq 'ARRAY') {
      ## process parallel tasks group ##
      # $task = [[@tasks], ...]
      dbg1 and debug("## start parallel section ##");
      my @thrs;
      push @thrs, threads->create({context => 'list'}, \&process_tasks, $_, $output) for @$task;
      for my $thr (@thrs) {
        if ($is_master) {
          $output->flush, m_sleep(0.1) while !$thr->is_joinable();
        }
        my ($all, $failed, $skipped) = $thr->join;
        $output->flush;
        push @all, @$all;
        push @failed, @$failed;
        push @skipped, @$skipped;
      }
      dbg1 and debug("## end parallel section ##");
      next;
    }

    ## process task ##
    my $o = $output->open($task->index);
    $o->push('----- ', $task->name, " -----\n") if $debug;
    $task->set_debug(1) if $debug;
    $task->DEBUG_RESET('main_task_timer');
    my ($res, $msg);
    try {
      $res = ('Plugins::'.$task->plugin)->process_wrp($o, $task, $db);
    }
    catch {
      $msg = format_msg($@);
      $res = 0;
    };
    $task->DEBUG_T('main_task_timer', 'task \''.$task->name.'\' finished');

    push @all, $task;
    my $status;
    if ($res eq 'skipped') {
      $status = 'skipped........';
      push @skipped, $task;
    } elsif ($res) {
      $status = 'ok.............';
    } else {
      $status = 'failed ['.$task->id.']........';
      push @failed, $task;
    }
    $o->push($status, $task->name, "\n", (defined $msg ? $msg : ())) if !$res || !$quiet;
    $output->close($task->index);
  }
  (\@all, \@failed, \@skipped)
}
