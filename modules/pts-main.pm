use strict;
use warnings;

our $db;
our $args;
our $failed_fname;
our $script_start_time;

## obtain tasks to execute ##
my @tasks = map { -f $_ ? load_task_set($db, $_) : $db->new_task($_) }
                @{$args->arg('taskset')};

## open file $failed_fname ##
my $failed_file;
if ($failed_fname) {
  open $failed_file, '>', $failed_fname
      or die "Can not write to file '$failed_fname': $!\n";
}

my $start_time = 0;
$start_time = time if dbg1;

## load plugins ##
load_plugins(@tasks);

## construct task sequence ##
our $has_parallel = 0;
my $prepared = prepare_tasks(@tasks);
dbg1 and dprint_tasks($prepared);

## process tasks ##
my ($process_func, $process_func_descr) =
    !$has_parallel ? (\&process_tasks_seq              => 'sequentially'      )
  : use_mce        ? (\&ParallelWithMCE::process_tasks => 'MCE'               )
  :                  (\&process_tasks                  => 'threads-like forks');
dbg1 and dprint("processing method: $process_func_descr");
my $stats = $process_func->($prepared);
my $all     = $stats->{all}    || [];
my $failed  = $stats->{failed} || [];
my $skipped = $stats->{skipped}|| [];

## print statistics ##

dbg1 and dprint(sprintf "tasks time = %.3f", time - $start_time);
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
     if $args->is_opt('stat') || (!quiet && @$all > 1);

## write failed tasks ##
if (@$failed){
  if ($failed_fname){
    print $failed_file $_->id."\n" for @$failed;
    close $failed_file;
    dbg1 and dprint("Failed tasks were written to file '$failed_fname'.\n");
  }
  exit 1
}

## remove failed file on success ##
if ($failed_file){
  close $failed_file;
  unlink $failed_fname;
}

##### END #####

sub dprint
{
  print "DEBUG: $_\n" for split /\n/, join '', @_;
}

sub load_task_set
{
  my ($db, $fname) = @_;
  dbg1 and dprint("load task set from file $fname");
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
  dbg1 and dprint("$fname: loaded tasks:\n", map('  '.$_->id."\n", @ret));
  @ret
}

sub load_plugins
{
  my @tasks = @_;
  for my $plugins_pdir (PtsConfig->plugins_parent_dirs) {
    eval "use lib '$plugins_pdir'";
    die $@ if $@;
    dbg1 and dprint('plugins dir = '.catfile($plugins_pdir, 'Plugins'));
  }

  my @failed;
  my %plugins;
  for my $task (@tasks){
    my $pname = $task->plugin;
    next if exists $plugins{$pname};
    dbg1 and dprint("load plugin $pname");
    (my $req_pname = $pname) =~ s#::#/#g;
    eval {
      no strict 'refs';
      *{"Plugins::${pname}::dbg1"} = *dbg1;
      require "Plugins/$req_pname.pm"
    };
    if ($@){
      print $@;
      push @failed, $pname;
    }
    $plugins{$pname} = !$@;
    if (dbg2 && exists &{"Plugins::${pname}::process"}) {
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
  join '', map "# $_\n", split /\n/, join '', @_
}

sub m_sleep
{
  select undef, undef, undef, $_[0]
}

# $stats = {all => [], failed => [], skipped => [],};
# # $out should have 'push' method;
# process_task($task, $out, $stats);
sub process_task
{
  my ($task, $o, $stats) = @_;
  dbg1 and $o->push('----- ', $task->name, " -----\n");
  dbg1 and $task->set_debug(1);
  dbg1 and $task->DEBUG_RESET('main_task_timer');
  my ($res, $msg);
  try {
    $res = ('Plugins::'.$task->plugin)->process_wrp($o, $task, $db);
  }
  catch {
    $msg = format_msg($@);
    $res = 0;
  };
  dbg1 and $task->DEBUG_T('main_task_timer', 'task \''.$task->name.'\' finished');

  push @{$stats->{all}}, $task;
  my $status;
  if ($res eq 'skipped') {
    $status = 'skipped........';
    push @{$stats->{skipped}}, $task;
  } elsif ($res) {
    $status = 'ok.............';
  } else {
    $status = 'failed ['.$task->id.']........';
    push @{$stats->{failed}}, $task;
  }
  $o->push((defined $msg ? $msg : ()), $status, $task->name, "\n") if !$res || !quiet;
}

# my $stats = process_tasks_seq(\@prepared_tasks);
# ## $stats = {all => [@all], failed => [@failed], skipped => [@skipped],}
sub process_tasks_seq
{
  my $prepared = shift;
  my $stats = {};
  my $o = ForkedOutput::MainThreadOutput->new;
  for my $t (@$prepared) {
    process_task($t, $o, $stats);
  }
  $stats
}

# my $stats = process_tasks(\@prepared_tasks);
# ## $stats = {all => [@all], failed => [@failed], skipped => [@skipped],}
sub process_tasks
{
  my $prepared = shift;
  STDOUT->autoflush(1);
  my $output = ForkedOutput->new;
  my $ret = m_process_tasks($prepared, $output);
  unlink $_ for $output->filenames;
  $ret
}

sub m_process_tasks
{
  my $tasks = shift;
  my $output = shift;
  my $is_master = $output->is_main_thread;

  my $stats = {};

  for my $task (@$tasks) {
    if (ref $task eq 'ARRAY') {
      ## process parallel tasks group ##
      # $task = [[@tasks], ...]
      dbg1 and dprint("## start parallel section ##");
      my @thrs;
      push @thrs, ForkedChild->create(\&m_process_tasks, $_, $output) for @$task;
      for my $thr (@thrs) {
        if ($is_master) {
          $output->flush, m_sleep(0.1) while !$thr->is_joinable;
        }
        my ($rs) = $thr->join;
        $output->flush;
        push @{$stats->{$_}}, @{$rs->{$_}} for keys %$rs;
      }
      dbg1 and dprint("## end parallel section ##");
      next;
    }

    ## process task ##
    my $o = $output->open($task->index);
    main::process_task($task, $o, $stats);
    $output->close($task->index);
  }
  $stats
}

1
