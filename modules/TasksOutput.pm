package TasksOutput;
use strict;
use threads;
use threads::shared;

{
  package QueuedOutput;
  sub new
  {
    bless [], shift
  }
  sub push
  {
    my $self = shift;
    push @$self, join '', @_;
  }
  sub flush
  {
    my $self = shift;
    print @$self;
    @$self = ();
  }
}

sub new
{
  my $class = shift;
  bless shared_clone({
    main_tid => threads->tid,
    outs => [],
    cur_ind => 0,
  }), $class
}

sub open
{
  my $self = shift;
  my $ind = shift;
  my $out = shared_clone(QueuedOutput->new);
  $self->{outs}[$ind] = shared_clone({
    closed => 0,
    out => $out,
  });
  $out
}

sub flush
{
  my $self = shift;
  return if $self->{main_tid} != threads->tid;

  my $i = $self->{cur_ind};
  my $outs = $self->{outs};
  my $n = @$outs;
  $outs->[$i++]{out}->flush while $i < $n && $outs->[$i]{closed};
  $self->{cur_ind} = $i;
}

sub close
{
  my $self = shift;
  my $ind = shift;
  $self->{outs}[$ind]{closed} = 1;
  $self->flush;
}

1
