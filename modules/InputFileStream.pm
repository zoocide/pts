package InputFileStream;
# my $ifs = InputFileStream->new($filename);
sub new
{
  my $class = shift;
  my $fname = shift;
  bless {
    fname => $fname,
    read_fh => undef,
    pos => 0,
  }, $class
}

# $ifs->seek_end; #< returns $ifs for chaining
sub seek_end
{
  if (open my $f, '<', $_[0]{fname}) {
    seek $f, 0, 2;
    $_[0]{pos} = tell $f;
    close $f;
  }
  $_[0]
}

# my $fh = $ifs->begin_read or die "$!";
sub begin_read
{
  my $f = $_[0]{read_fh};
  return $f if defined $f;
  open $f, '<', $_[0]{fname} or return;
  seek $f, $_[0]{pos}, 0;
  $_[0]{read_fh} = $f
}

# $ifs->end_read;
sub end_read
{
  my $f = $_[0]{read_fh};
  return if !defined $f;
  $_[0]{pos} = tell $f;
  close $f;
  $_[0]{read_fh} = undef;
}

# my @lines = $ifs->read_update;
sub read_update
{
  my $f = $_[0]->begin_read or return;
  my @lines = <$f>;
  $_[0]->end_read;
  @lines
}

sub DESTROY {
  close $_[0]{read_fh} if defined $_[0]{read_fh};
}

sub CLONE_SKIP { 1 }

1
