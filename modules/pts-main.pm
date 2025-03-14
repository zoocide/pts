use strict;
use warnings;
use Cwd qw(realpath);
use File::Spec::Functions qw(:ALL);
use ForkedOutput;

our $db;
our $args;
our $failed_fname;
our $script_start_time;
our $terminated;

$SIG{INT} = sub {
  $terminated = 1;
  die "terminated\n";
};

my $delete_failed_file = defined $failed_fname;
my $failed_fname_abs = defined $failed_fname ? m_realpath(rel2abs($failed_fname)) : '';

use constant use_mce => !no_mce && (eval{ require ParallelWithMCE; 'ParallelWithMCE' } || (force_mce && die $@));
use constant use_threads => !use_mce && $^O eq 'MSWin32' && require ParallelWithThreads;
use if !use_mce && !use_threads, 'ParallelWithForks';

## obtain tasks to execute ##
dbg2 and dprint("load tasks");
dbg2 and my $lt_time = time;
update_plugins_path();
my @tasks = map { is_task_set($_) ? load_task_set($db, $_) : $db->new_task($_) }
                @{$args->arg('taskset')};
if (my @failed_plugins = $db->failed_plugins) {
  die "ERROR! Can not load plugins: ".join(', ', @failed_plugins)."\n";
}
dbg2 and dprint_t(time - $lt_time, 'tasks loaded');

## try to open file $failed_fname ##
if ($failed_fname) {
  open my $fh, '>>', $failed_fname
      or die "Can not write to file '$failed_fname': $!\n";
  close $fh;
}

my $start_time = time if dbg1;

## construct task sequence ##
our $has_parallel = 0;
my $prepared = prepare_tasks(@tasks);
dbg1 and dprint_tasks($prepared);

## process tasks ##
my ($process_func, $process_func_descr) =
    !$has_parallel ? (\&process_tasks_seq              => 'sequentially'      )
  : use_mce        ? (\&ParallelWithMCE::process_tasks => 'MCE'               )
  : use_threads    ? (\&ParallelWithThreads::process_tasks => 'threads'       )
  :                (\&ParallelWithForks::process_tasks => 'threads-like forks');
dbg1 and dprint("processing method: $process_func_descr");
my $stats = $process_func->($prepared);
my $all     = $stats->{all}    || [];
my $failed  = $stats->{failed} || [];
my $skipped = $stats->{skipped}|| [];

## print statistics ##

dbg1 and dprint(sprintf "tasks time = %.3f", time - $start_time);
printf "total time = %.3f\n", time - $script_start_time if $args->is_opt('ttime');

if (dbg2) {
  my %h = map {$_ => 1} @$failed, @$skipped;
  dprint("ok: [", $_->index, "] ", $_->id) for grep !$h{$_}, @$all;
  dprint("skipped: [", $_->index, "] ", $_->id) for @$skipped;
  dprint("failed: [", $_->index, "] ", $_->id) for @$failed;
}

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
     if $args->is_opt('stat') || (!quiet && @$all > 1);

## write failed tasks ##
if (@$failed){
  if ($failed_fname){
    open my $fh, '>', $failed_fname
      or die "Can not write to file '$failed_fname': $!\n";
    print $fh $_->id."\n" for @$failed;
    close $fh;
    dbg1 and dprint("Failed tasks were written to file '$failed_fname'.\n");
  }
  return 1  # FAILURE
}
else {
  ## remove failed file on success ##
  if ($failed_fname && $delete_failed_file && -e $failed_fname){
    unlink $failed_fname;
  }
  return 0  # SUCCESS
}

##### END #####

sub dprint
{
  print clr_dbg."DEBUG: $_".clr_end."\n" for split /\n/, join '', @_;
}

sub dprint_t
{
  my $t = sprintf '%.6f', shift;
  print clr_dbg, "DEBUG [${t}s]: ", @_, clr_end, "\n";
}

sub m_dirname
{
  catpath((splitpath($_[0]))[0,1])
}

sub m_realpath
{
  my $r = -e $_[0] ? realpath($_[0]) : $_[0];
  file_name_is_absolute($_[0])
    ? ($r // $_[0])
    : (defined $r ? abs2rel($r) : canonpath($_[0]))
}

# 'filename' => './filename'
sub rel_fname
{
  my ($disk, $dirs, $f) = splitpath($_[0]);
  $disk eq '' && $dirs eq '' ? catpath('', curdir, $f) : $_[0]
}

sub is_task_set
{
  my $spec = shift;
  my ($disk, $dir) = splitpath($spec);
  return 0 if $disk eq '' && $dir eq '';
  $spec !~ /.\.conf$/ && -f $spec && !-x $spec
}

sub load_task_set
{
  my $db = shift;
  my $fname = shift;
  my $cur_dir = shift // curdir;

  $cur_dir = file_name_is_absolute($fname)
           ? m_dirname($fname)
           : canonpath(catdir($cur_dir, m_dirname($fname)));

  dbg1 and dprint("load task set from file '$fname'");
  my @ret;
  $delete_failed_file &&= $failed_fname_abs ne m_realpath(rel2abs($fname));
  open(my $f, '<:crlf', $fname) || throw OpenFileError => $fname;
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
    $s =~ s/^\\([#\\])/$1/; #< rules 2 and 3

    ## get a filename from the specification string ##
    my $short_id = $s;
    my $args = ($short_id =~ s/\s*:(?:[^\\]|$).*//)
             ? substr $s, $-[0]
             : '';
    my $short_decl = $short_id eq $s;

    ## set the path relative to the  $cur_dir ##
    if (!file_name_is_absolute($short_id)) {
      my (undef, $t_dir, $t_fname) = splitpath($short_id);
      if ($t_dir ne '') {
        ## a relative path specified ##
        # `length $t_dir > 2` - Is a reason for $t_dir to be optimized?
        if ($cur_dir ne curdir || length $t_dir > 2) {
          $t_dir = m_realpath(catdir($cur_dir, $t_dir));
          $s = catpath('', $t_dir, $t_fname).$args;
        }
      }
    }

    ## try to load the nested task-set file ##
    if ($short_decl && is_task_set($s)) {
      try { push @ret, load_task_set($db, $s) }
      catch { throw TextFileError => $fname, $ln, $@ };
      next;
    }

    ## try to load the task ##
    try { push @ret, $db->new_task($s) }
    catch { throw TextFileError => $fname, $ln, $@ };
  }
  close $f;
  dbg1 and dprint("$fname: loaded tasks:\n", map('  '.$_->id."\n", @ret));
  @ret
}

sub update_plugins_path
{
  for my $plugins_pdir (PtsConfig->plugins_parent_dirs) {
    eval "use lib '$plugins_pdir'";
    die $@ if $@;
    dbg1 and dprint('plugins dir = '.catfile($plugins_pdir, 'Plugins'));
  }
}

sub index_tasks
{
  my $tasks = shift;
  my $i = shift || 0;
  our $has_parallel;
  for my $t (@$tasks) {
    if (ref $t eq 'ARRAY') {
      $has_parallel = 1;
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
      dbg2 and dprint("prepare '", $t->id, "' task[$i]");
      # An exception is not captured to abort the execution.
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
  dprint($pref, '[');
  for my $t (@$tasks) {
    if (ref $t eq 'ARRAY') {
      dprint($pref.'  ## start parallel section ##');
      dprint_tasks($_, $pref.'  ') for @$t;
      dprint($pref.'  ## end parallel section ##');
      next;
    }
    dprint($pref.'  ', $t->index, ':', $t->id);
  }
  dprint($pref, ']');
}

sub format_msg
{
  join '', map clr_red."# $_".clr_end."\n", split /\n/, join '', @_
}

# $stats = {all => [], failed => [], skipped => [],};
# # $out should have 'push' method;
# If $res is defined, the plugin->process method is not executed
# and the specified value is used as a result.
# process_task($task, $out, $stats, $res);
sub process_task
{
  my ($task, $o, $stats, $res) = @_;
  dbg1 and $o->push('----- ', $task->fullname, " -----\n");
  dbg1 and $task->set_debug(1);
  dbg1 and Plugins::Base::dtimer_reset('main_task_timer');
  dbg1 and local $Plugins::Base::out = $o;
  dbg2 and Plugins::Base::dprint('[', $task->index, '] ', $task->id);
  dbg2 and Plugins::Base::dprint('plugin = '.$task->plugin);

  my @msg;
  if (!defined $res) {
    try {
      $res = ('Plugins::'.$task->plugin)->process_wrp($o, $task, $db);
    }
    catch {
      push @msg, format_msg($@);
      $res = 0;
    };
    dbg1 and Plugins::Base::dprint_t('main_task_timer', 'task \''.$task->fullname.'\' finished');
  }

  push @{$stats->{all}}, $task;
  my $status;
  if ($res eq 'skipped') {
    $status = clr_gray.'skipped....... '.clr_end;
    push @{$stats->{skipped}}, $task;
  } elsif ($res) {
    $status = clr_green."ok............ ".clr_end;
  } else {
    push @msg, clr_bg_red.'# task failed ['.$task->id."]".clr_end."\n";
    $status = clr_red."not ok........ ".clr_end;
    push @{$stats->{failed}}, $task;
  }
  $o->push(@msg, $status, $task->fullname, "\n") if !$res || !quiet;
}

# my $stats = process_tasks_seq(\@prepared_tasks);
# ## $stats = {all => [@all], failed => [@failed], skipped => [@skipped],}
sub process_tasks_seq
{
  my $prepared = shift;
  my $stats = {};
  my $o = ForkedOutput::MainThreadOutput->new;
  for my $t (@$prepared) {
    process_task($t, $o, $stats, $terminated ? 'skipped' : ());
  }
  $stats
}

1
