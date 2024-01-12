package ProcessViewer;

our $VERSION = v0.3.0;

=head1 SYNOPSIS

  $pv = ProcessViewer->new;
  my @pids = $pv->update->all_pids;
  my $number_of_processes = @pids;
  my $proc = $pv->process($PID);
  # getters:
  # $proc->name;
  # $proc->pid;
  # $proc->ppid;
  # $proc->cmd;

  my @children = $pv->children($PID);
  # $children[0]->name; ...

  my @all_procs = $pv->all_processes;
  # $all_procs[0]->name; ...

=cut

use constant win32 => $^O eq 'MSWin32';

our $msg_prefix = '';
our $MSGS_IMMEDIATE = 0;

sub new
{
  my $class = shift;

  my $self = bless {
    procs => {}, #{$pid => $ProcessInfo_obj, ...}
    children => {}, #{$ppid => [@ProcessInfo_objs], ...}
  }, $class;
  $self
}

sub update
{
  my $self = shift;

  ## reset processes info ##
  $self->{procs} = {},
  $self->{children} = {},

  ## obtain processes info ##
  local $msg_prefix = $msg_prefix.'ProcessViewer::update:';
  win32
    ? $self->m_update_by_wmic
    : $self->m_update_by_ps;

  $self
}

#my @pids = $pv->all_pids;
sub all_pids { keys %{$_[0]{procs}} }
#my @ProcessInfo_objs = $pv->all_processes;
sub all_processes { values %{$_[0]{procs}} }
#my $ProcessInfo_obj = $pv->process($pid);
sub process { exists $_[0]{procs}{$_[1]} ? $_[0]{procs}{$_[1]} : undef }
#my @ProcessInfo_objs = $pv->children($pid);
sub children { exists $_[0]{children}{$_[1]} ? @{$_[0]{children}{$_[1]}} : () }

sub m_update_by_ps
{
  my $self = shift;
  my $ps_cmd = 'ps -Al';
  my @text = `$ps_cmd`;
  $? and die "`$ps_cmd` failed with code $?";
  @text or die "`$ps_cmd` returned empty list";
  my $i = 0;
  my %cols = map {(uc $_ => $i++)} split /\s+/, shift @text;
  exists $cols{$_} or die "`$cmd` does not show the $_ field" for qw(PID PPID CMD);
  for (@text) {
    my @info = split /\s+/;
    my $pid = $info[$cols{PID}];
    my $ppid = $info[$cols{PPID}];
    my $cmd = join ' ', @info[$cols{CMD}..$#info];
    my $obj = ProcessInfo->new($pid, $cmd, $ppid, $cmd);
    $self->{procs}{$pid} = $obj;
    push @{$self->{children}{$ppid}}, $obj;
  }
}

#my $self->m_update_by_wmic;
sub m_update_by_wmic
{
  my $self = shift;
  my $text = `wmic process list full`;
  $? and die "wmic.exe failed";
  $text or die "wmic.exe returned empty list";
  for (split /(?:\r\n){2,}/, $text) {
    next if $_ eq '';
    my $obj = m_parse_process_info($_);
    $self->{procs}{$obj->pid} = $obj;
    push @{$self->{children}{$obj->ppid}}, $obj;
  }
  m_print_msgs();
}

sub m_parse_process_info
{
  my $text = shift;

  local our $msg_prefix = $msg_prefix.'m_parse_process_info:';

  my ($name, $pid, $ppid, $cmd);
  my %h = (
    CommandLine => \$cmd,
    CSName => undef,
    Description => undef,
    ExecutablePath => undef,
    ExecutionState => undef,
    Handle => undef,
    HandleCount => undef,
    InstallDate => undef,
    KernelModeTime => undef,
    MaximumWorkingSetSize => undef,
    MinimumWorkingSetSize => undef,
    Name => \$name,
    OSName => undef,
    OtherOperationCount => undef,
    OtherTransferCount => undef,
    PageFaults => undef,
    PageFileUsage => undef,
    ParentProcessId => \$ppid,
    PeakPageFileUsage => undef,
    PeakVirtualSize => undef,
    PeakWorkingSetSize => undef,
    Priority => undef,
    PrivatePageCount => undef,
    ProcessId => \$pid,
    QuotaNonPagedPoolUsage => undef,
    QuotaPagedPoolUsage => undef,
    QuotaPeakNonPagedPoolUsage => undef,
    QuotaPeakPagedPoolUsage => undef,
    ReadOperationCount => undef,
    ReadTransferCount => undef,
    SessionId => undef,
    Status => undef,
    TerminationDate => undef,
    ThreadCount => undef,
    UserModeTime => undef,
    VirtualSize => undef,
    WindowsVersion => undef,
    WorkingSetSize => undef,
    WriteOperationCount => undef,
    WriteTransferCount => undef,
  );

  for (split /\r\n/, $text) {
    my ($k, $v) = /^(\w+)=(.*)/;
    defined $k or die "wrong key=value pair '$_'";
    if (!exists $h{$k}) {
      m_msg("unknown field name '$k'");
      next;
    }
    my $var = $h{$k};
    next if !defined $var;
    $$var = $v;
  }

  ProcessInfo->new($pid, $name, $ppid, $cmd)
}

sub m_msg
{
  our (@msgs, $msg_prefix);
  my $msg = $msg_prefix.(join '', @_);

  if ($MSGS_IMMEDIATE) {
    print STDERR $msg, (substr($msg, -1) eq "\n" ? '' : "\n");
    return;
  }

  push @msgs, $msg;
}

sub m_print_msgs
{
  our @msgs;
  my %h;
  for (@msgs) {
    next if ++$h{$_} > 1;
    print STDERR $_, (substr($_, -1) eq "\n" ? '' : "\n");
  }
  @msgs = ();
}



package ProcessInfo;

sub new
{
  my $class = shift;
  my ($pid, $name, $ppid, $cmd) = @_;
  bless {
    pid => $pid,
    ppid => $ppid,
    name => $name,
    cmd => $cmd,
  }, $class
}

sub pid { $_[0]{pid} }
sub ppid { $_[0]{ppid} }
sub name { $_[0]{name} }
sub cmd { $_[0]{cmd} }

1
