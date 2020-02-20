package TasksOutput;
use strict;
use threads;
use threads::shared;
use Thread::Queue;

{
  package QueuedOutput;
  sub new
  {
    bless [Thread::Queue->new], shift
  }
  sub push
  {
    my $self = shift;
    $self->[0]->enqueue(join '', @_);
  }
  sub flush
  {
    my $self = shift;
    my $q = $self->[0];
    my $n = $q->pending or return;
    print $q->dequeue_nb($n);
  }
}

{
  package MainThreadOutput;
  sub new
  {
    my $self;
    bless \$self, shift
  }
  sub push
  {
    shift;
    print @_;
  }
  sub flush
  {
  }
}

# my $to = TasksOutput->new;
sub new
{
  my $class = shift;
  bless shared_clone({
    main_tid => threads->tid,
    outs => [],
    cur_ind => 0,
  }), $class
}

#my $is_main_thread = $to->is_main_thread;
sub is_main_thread
{
  $_[0]{main_tid} == threads->tid
}

#my $out = $to->open($index);
sub open
{
  my $self = shift;
  my $ind = shift;
  my $out_class = $self->is_main_thread ? 'MainThreadOutput' : 'QueuedOutput';
  my $out = shared_clone($out_class->new);
  $self->{outs}[$ind] = shared_clone({
    closed => 0,
    out => $out,
  });
  $out
}

#my $to->flush;
sub flush
{
  my $self = shift;
  return if $self->{main_tid} != threads->tid;

  my $i = $self->{cur_ind};
  my $outs = $self->{outs};
  for (my $n = @$outs; $i < $n; $i++) {
    $outs->[$i]{out}->flush;
    last if !$outs->[$i]{closed};
  }
  $self->{cur_ind} = $i;
}

#my $to->close($index);
sub close
{
  my $self = shift;
  my $ind = shift;
  $self->{outs}[$ind]{closed} = 1;
  $self->flush;
}

1
