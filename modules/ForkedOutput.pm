package ForkedOutput;
use strict;
use Socket;
use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
use File::Temp qw(tempfile);

our $VERSION = v0.2.1;

=head1 SYNOPSIS

  use ForkedOutput;

  my $output = ForkedOutput->new;

  ## child ##
  # $ind is a index of child. It should be in range 0..$#children.
  my $out = $output->open($ind, "output_file_$ind.txt");
  $out->push(@text);
  $output->close($ind);

  ## parent ##
  # 'flush' will print output of child 0 until it finish.
  # Then do the same for child 1 and so on.
  $output->flush while child_is_working();
  $output->flush;

  unlink $_ for $output->filenames;

=cut

{
  package ForkedOutput::Queue;
  use strict;
  use Socket;
  sub new
  {
    socketpair(my $read, my $write, AF_UNIX, SOCK_STREAM, PF_UNSPEC);
    $write->autoflush(1);
    ForkedOutput::m_set_nonblocking($read);
    bless {
      fd_read => $read,
      fd_write => $write,
    }, shift
  }
  sub push
  {
    my $self = shift;
    my $fd = $self->{fd_write};
    print $fd @_;
  }
  sub flush
  {
    my $self = shift;
    my ($s, @chunks);
    CORE::push @chunks, $s while sysread $self->{fd_read}, $s, 1024;
    return if !@chunks;
    print @chunks;
  }
}

{
  package ForkedOutput::FileQueue;
  use strict;
  use Carp;
  use InputFileStream;
  # my $qout = ForkedOutput::FileQueue->new($fname, $opt_rdo);
  sub new
  {
    my $class = shift;
    my $fname = shift;
    my $read_only = shift;
    my $f;
    if (!$read_only) {
      open $f, '>', $fname or die "cannot open file '$fname': $!";
      $f->autoflush(1);
    }
    bless {
      sread => InputFileStream->new($fname),
      fd_write => $f,
      fname => $fname,
    }, $class
  }
  sub push
  {
    my $self = shift;
    my $fd = $self->{fd_write};
    $fd or croak __PACKAGE__.": cannot push into readonly object.";
    print $fd @_;
  }
  sub flush
  {
    my $self = shift;
    my @chunks = $self->{sread}->read_update;
    return if !@chunks;
    print @chunks;
  }
  sub close
  {
    close $_[0]{fd_write} if $_[0]{fd_write};
  }
  sub DESTROY
  {
    local($., $@, $!, $^E, $?);
    CORE::close $_[0]{fd_write} if $_[0]{fd_write};
  }
}

{
  package ForkedOutput::MainThreadOutput;
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

# my $fo = ForkedOutput->new;
sub new
{
  my $class = shift;
  #print "DEBUG: '$_'\n" for @_;
  socketpair(my $srv_read, my $srv_write, AF_UNIX, SOCK_STREAM, PF_UNSPEC);
  $srv_write->autoflush(1);
  m_set_nonblocking($srv_read);
  bless {
    main_pid => $$,
    outs => [],
    fnames => [],
    cur_ind => 0,
    srv_read => $srv_read,
    srv_write => $srv_write,
  }, $class
}

sub filenames { @{$_[0]{fnames}} }

#my $is_main_thread = $fo->is_main_thread;
sub is_main_thread
{
  $_[0]{main_pid} == $$
}

#my $out = $fo->open($index, $opt_fname);
sub open
{
  my $self = shift;
  my $ind = shift;
  my $fname = shift; #< optional argument
  my $out = $self->m_mk_out($ind, $fname);
  $self->{outs}[$ind] = {
    closed => 0,
    out => $out,
  };
  $self->m_srv_msg("$ind:open[$self->{fnames}[$ind]]");
  $out
}

#my $fo->flush;
sub flush
{
  my $self = shift;
  return if $self->{main_pid} != $$;

  $self->m_update_status;

  my $i = $self->{cur_ind};
  my $outs = $self->{outs};
  #print scalar @$outs, "\n";
  for (my $n = @$outs; $i < $n; $i++) {
    last if !exists $outs->[$i]{out};
    $outs->[$i]{out}->flush;
    last if !$outs->[$i]{closed};
  }
  $self->{cur_ind} = $i;
}

# $fo->close($index);
sub close
{
  my $self = shift;
  my $ind = shift;
  $self->{outs}[$ind]{closed} = 1;
  my $out = $self->{outs}[$ind]{out};
  $out->close if $out->can('close');
  $self->m_srv_msg("$ind:close");
  $self->flush;
}

# m_set_nonblocking($file_handle);
sub m_set_nonblocking
{
  my $fh = shift;
  if ($^O eq 'MSWin32') {
    my $nonblocking = "1";
    #FIONBIO = 0x8004667ea
    ioctl($fh, 0x8004667e, $nonblocking) or die "ioctl(FIONBIO) failed: $!\n";
  }
  else {
    my $flags = fcntl($fh, F_GETFL, 0) or die "fcntl(F_GETFL) failed: $!\n";
    fcntl($fh, F_SETFL, $flags|O_NONBLOCK) or die "fcntl(F_SETFL) failed: $!\n";
  }
}

# $self->m_update_status;
sub m_update_status
{
  my $self = shift;
  my $f = $self->{srv_read};
  my ($s, @chunks);
  push @chunks, $s while sysread $f, $s, 1024;
  return if !@chunks;
  for my $line (split /\n/, join '', @chunks) {
    next if $line =~ /^\s*$/;
    if ($line =~ /^(\d+):open\[(.+)]$/) {
      $self->{outs}[$1]{closed} = 0;
      $self->{outs}[$1]{out} ||= $self->m_mk_out($1, $2, 1);
    }
    elsif ($line =~ /^(\d+):close$/) {
      $self->{outs}[$1]{closed} = 1;
      $self->{outs}[$1]{out} or die "output was not opened";
    }
    else {
      print 'ERROR:'.__PACKAGE__.": unexpected service message '$line'\n";
    }
  }
}

# my $out = $self->m_mk_out($ind, $opt_fname, $opt_thr);
sub m_mk_out
{
  my ($self, $ind, $fname, $opt_thr) = @_;
  undef local $^W;
  $fname ||= (tempfile("out_${ind}_XXXX", OPEN => 0, SUFFIX => '.txt'))[1];
  $self->{fnames}[$ind] = $fname;
  my $out_class = __PACKAGE__.'::'
    .(!$opt_thr && $self->is_main_thread ? 'MainThreadOutput' : 'FileQueue');
  $out_class->new($fname, $opt_thr)
}

# $self->m_srv_msg($msg)
sub m_srv_msg
{
  my $f = $_[0]{srv_write};
  print $f "$_[1]\n";
}

sub DESTROY
{
  local($., $@, $!, $^E, $?);
  my $self = shift;
  CORE::close $self->{srv_read} if $self->{srv_read};
  CORE::close $self->{srv_write} if $self->{srv_write};
  #print "~ForkedOutput\n";
}

1
