package ForkedChild;
use strict;
use Socket;
use Storable qw(store_fd fd_retrieve);
use POSIX qw(WNOHANG);

our $VERSION = v0.1.1;

=head1 SYNOPSIS

  use ForkedChild;

  sub child_process
  {
    my @args = @_;
    ...
    return @ret_array
  }

  my $child = ForkedChild->create(\&child_process, @args);
  sleep(1) while !$child->is_joinable;
  my @ret = $child->join;

=cut

# my $child = ForkedChild->create(\&sub, @args);
sub create
{
  my $class = shift;
  my $sub = shift;
  socketpair(my $child_ret, my $ret, AF_UNIX, SOCK_STREAM, PF_UNSPEC);
  my $pid;
  if ($pid = fork) {
    close $ret;
  }
  else {
    defined $pid or die "cannot fork";
    close $child_ret;
    my @ret = ($sub->(@_));
    $ret->autoflush(1);
    store_fd(\@ret, $ret);
    shutdown($ret, 2);
    exit 0;
  }

  bless {
    fd_ret => $child_ret,
    pid => $pid,
    done => 0,
  }, $class
}

# my @ret = $child->join;
sub join
{
  my $self = shift;
  my $ret = fd_retrieve($self->{fd_ret});
  close $self->{fd_ret};
  waitpid $self->{pid}, 0;
  @$ret
}

# my $bool = $child->is_joinable;
sub is_joinable
{
  waitpid($_[0]{pid}, WNOHANG) == 0 ? 0 : 1
}

1
