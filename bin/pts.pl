#!/usr/bin/perl -w
use strict;
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

BEGIN{ eval{ require 'Time/HiRes.pm'; Time::HiRes->import('time') } }

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
  '0.3.0',
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
  },
  groups => {
    OPTIONS => [qw(quiet stat debug tasks_dir plugins_dir failed)],
  },
  use_cases => {
    main => ['OPTIONS taskset...', 'Process a set of tasks.'
             .' There is a tasks database, from which you can select tasks to execute.'
             .' Also you can sepcify files, containing tasks names.'],
    list => ['tasks_dir? list', 'Print all tasks in database.'],
  },
);
$args->parse;

## list tasks ##
if ($args->use_case eq 'list'){
  print $_, "\n" for sort $db->all_task_ids;
  exit 0;
}

## obtain tasks to execute ##
my @tasks = map { -f $_ ? load_task_set($db, $_) : $db->get_task($_) }
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

my @failed;
my @skipped;
## main loop ##
for my $task (@tasks){
  print '===== ', $task->name, " =====\n" if !$quiet;
  $task->set_debug(1) if $debug;
  $task->DEBUG_RESET('main_task_timer');
  my $res;
  try{
    $res = ('Plugins::'.$task->plugin)->process($task, $db);
  }
  catch{
    print $@;
    $res = 0;
  };
  $task->DEBUG_T('main_task_timer', 'task \''.$task->name.'\' finished');

  my $status;
  if ($res eq 'skipped'){
    $status = 'skipped';
    push @skipped, $task;
  } elsif ($res){
    $status = 'complete';
  } else {
    $status = 'failed ['.$task->id.']';
    push @failed, $task;
  }
  print $task->name, ' ', $status, "\n" if !$res || !$quiet;
}

## print statistics ##

dbg1 and debug("total execution time = ", time - $start_time);
dbg2 and debug("total           time = ", time - $script_start_time);

my $num_total  = @tasks;
my $num_failed = @failed;
my $num_skipped = @skipped;
my $num_ok     = $num_total - ($num_failed + $num_skipped);

print "\nstatistics:"
     ,"\nnum total    = ", $num_total
     ,"\nnum complete = ", $num_ok
     ,"\nnum skipped  = ", $num_skipped
     ,"\nnum failed   = ", $num_failed
     ,"\n"
     if $args->is_opt('stat') || (!$quiet && @tasks > 1);

## write failed tasks ##
if (@failed){
  if ($failed_fname){
    print $failed_file $_->id."\n" for @failed;
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
    try { push @ret, $db->get_task($s) }
    catch { throw TextFileError => $fname, $ln, $@ };
  }
  close $f;
  debug("loaded tasks:\n", map('  '.$_->id."\n", @ret));
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
      eval { require "Plugins/$req_pname.pm" };
      if ($@){
        print $@;
        push @failed, $pname;
      }
      $plugins{$pname} = !$@;
  }
  @failed and die "ERROR! Can not load plugins: ".join(', ', @failed)."\n";
}
