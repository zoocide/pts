package ParallelWithMCE;
use strict;
use warnings;
use MCE;
use MCE::Queue;

BEGIN {
  *dprint = *main::dprint;
  *dbg1 = *main::dbg1;
  *dbg2 = *main::dbg2;
}

my $q_chunks = MCE::Queue->new;
my $q_done = MCE::Queue->new;
my $q_out = MCE::Queue->new;
my %chunks_wait; #< ($chunk_id => {$chunk_id => 1,},)
my %chunks_next; #< ($chunk_id => [@chunk_ids],)
my %chunks; #< ({id => [@chunk_tasks]}, );
our $max_par_workers = 1;

# $stats = ParallelWithMCE->process_tasks(\@prepared_tasks);
# ## $stats = {all => [@all], failed => [@failed], skipped => [@skipped],}
sub process_tasks
{
  my $tasks = shift;

  tasks2chunks(@$tasks);
  dbg1 and dprint_chunks();

  my $ncpu = MCE::Util::get_ncpu;
  my $nworkers = defined $main::num_procs
      ? $main::num_procs
      : $max_par_workers < $ncpu ? $max_par_workers : $ncpu;
  dbg1 and dprint("max_par_workers   = $max_par_workers");
  dbg1 and dprint("number_of_workers = $nworkers");
  our %stats = ();
  MCE->new(
    user_tasks => [
      {
        max_workers => $nworkers,
        user_func => \&worker,
      },
      {
        max_workers => 1,
        gather => \%stats,
        user_func => \&chunk_manager,
      },
      {
        max_workers => 1,
        user_func => \&output_manager,
      },
    ],
  )->run;
  ## sort stats by task index. ##
  @{$stats{$_}} = sort {$a->index <=> $b->index} @{$stats{$_}} for keys %stats;
  \%stats
}

sub worker
{
  my $wid = MCE->wid;
  #MCE->say("worker $wid started");
  while (my $chunk_id = $q_chunks->dequeue) {
    my @ctasks = @{$chunks{$chunk_id}};
    my %sts;
    for my $t (@ctasks) {
      #MCE->say("worker $wid: processing ", $t->id);
      my $o = ParallelWithMCE::TaskOutput->new($t->index);
      main::process_task($t, $o, \%sts);
      $o->close;
    }
    $q_done->enqueue([$chunk_id, \%sts]);
  }
  #MCE->say("worker $wid is exiting");
};

sub chunk_manager
{
  our %stats;
  my %wait_for = %chunks;
  #MCE->say("# chunk_manager started #");
  while (%wait_for && (my $data = $q_done->dequeue)) {
    on_chunk_done(@$data);
    delete $wait_for{$data->[0]};
  }
  $q_out->end;
  MCE->gather(%stats);
  #MCE->say("# chunk_manager finished #");
}

sub output_manager
{
  #MCE->say("# output_manager started #");
  while (my $data = $q_out->dequeue) {
    receive_output(@$data);
  }
  #MCE->say("# output_manager finished #");
}

sub receive_output
{
  my ($ti, $text) = @_;
  our $cur_ti;
  our @output; #< ({text => [@text], closed => $bool},)

  die "The manager received output from the closed task with index $ti.".
    " Current index is $cur_ti." if $output[$ti]{closed};

  if (defined $text) {
    if ($ti == $cur_ti) {
      MCE->print($text);
    }
    else {
      push @{$output[$ti]{text}}, $text;
    }
  }
  else {
    $output[$ti]{closed} = 1;
  }
  ## flush text ##
  while($output[$cur_ti]{closed}) {
    last if ++$cur_ti > $#output;
    print @{$output[$cur_ti]{text}} if exists $output[$cur_ti]{text};
    $output[$cur_ti]{text} = [];
  }
}

sub gather_stats
{
  my $sts = shift;
  our %stats;
  push @{$stats{$_}}, @{$sts->{$_}} for keys %$sts;
}

sub on_chunk_done
{
  my $cid = shift;
  my $sts = shift;

  #print "chunk $cid is done\n";
  for my $ncid (@{$chunks_next{$cid}}) {
    my $h = $chunks_wait{$ncid};
    delete $h->{$cid};
    next if %$h;
    $q_chunks->enqueue($ncid);
    delete $chunks_wait{$ncid};
  }
  $q_chunks->end if !%chunks_wait;
  gather_stats($sts);
}

# tasks2chunks(@tasks)
sub tasks2chunks
{
  local our $chunk_id = 1;
  return if !@_;
  our $cur_ti = 0;
  m_tasks2chunks([], @_);
}

# m_tasks2chunks(\@chunks2wait, @tasks)
sub m_tasks2chunks
{
  my $c2w = shift;
  $max_par_workers = 1;
  my @cchunk;
  for my $t (@_) {
    if (ref $t eq 'ARRAY') {
      m_complete_cur_chunk(\@cchunk, $c2w);
      my $mpw = 0;
      my @new_c2w;
      for my $p (@$t) {
        local $max_par_workers;
        push @new_c2w, m_tasks2chunks([@$c2w], @$p);
        $mpw += $max_par_workers;
      }
      @$c2w = @new_c2w;
      $max_par_workers = $mpw if $mpw > $max_par_workers;
      next;
    }
    push @cchunk, $t;
  }
  m_complete_cur_chunk(\@cchunk, $c2w);
  @$c2w
}

sub m_complete_cur_chunk
{
  my ($cc, $c2w) = @_;
  return if !@$cc;
  our $chunk_id;
  my $cid = $chunk_id++;
  $chunks{$cid} = [@$cc];
  if (@$c2w) {
    $chunks_wait{$cid} = {map {$_ => 1} @$c2w};
  }
  else {
    $q_chunks->enqueue($cid);
  }
  push @{$chunks_next{$_}}, $cid for @$c2w;
  @$cc = ();
  @$c2w = ($cid);
}

sub dprint_chunks
{
  local $" = ', ';
  for my $chunk_id (sort {$a<=>$b} keys %chunks) {
    my @ctasks = map '['.$_->id.']', @{$chunks{$chunk_id}};
    my @w = sort {$a<=>$b} keys %{$chunks_wait{$chunk_id}} if exists $chunks_wait{$chunk_id};
    dprint("chunk $chunk_id: tasks(@ctasks); waits for chunks (@w)");
  }
}

package ParallelWithMCE::TaskOutput;

sub new
{
  my $class = shift;
  my $index = shift;
  bless {
    ind => $index,
  }, $class
}

sub push
{
  my $self = shift;
  $q_out->enqueue([$self->{ind}, join('', @_)]);
}

sub close
{
  my $self = shift;
  $q_out->enqueue([$self->{ind}, undef]);
}

1
