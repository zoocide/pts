package Exceptions;
use base qw(Exporter);
use Exceptions::Exception;
use Exceptions::List;
our @EXPORT;
@EXPORT = qw(try throw catch exception2string string2exception make_exlist);

our $VERSION = '0.3.0';

=head1 SYNOPSIS

  use Exceptions;

  try {
    ## do something ##
    ...
    # throw exception of 'Exceptions::Exception' type
    throw Exception => "message";
    ...
    # throw exception of 'Exceptions::MyException' type
    throw MyException => $arg1, $arg2, $arg3;
  }
  catch {
    ## catch exception of 'Exceptions::MyException' type ##
  } 'Exceptions::MyException',
  catch {
    ## catch exception of 'Exceptions::Exception' type ##
    my $msg = $_[0]->msg;    ##< obtain message from exception
  } 'Exceptions::Exception',
  catch {
    ## catch all exceptions ##
  };

  try{
    ## do something ##
  }
  exception2string   ##< convert Exceptions::Exception object to string exception.
  catch{
    print $_[0];     ##< all exceptions prints normally
  };

=cut

sub throw
{
  die $@  if !@_;
  die $_[0] if ref $_[0];
  die +('Exceptions::'.(shift))->new(@_);
}

sub try (&;$)
{
  my $ret = eval { &{$_[0]} };
  if ($@){
    my $arr = $_[1];
    if ($arr){
      while (@$arr){
        my ($t, $s) = @{ shift @$arr };
        if (!defined $t){
          &$s($@);
          next;
        }
        return &$s($@) if (!$t || (ref $@ && $@->isa($t)));
      }
    }
    die $@;
  }
  $ret
}

sub catch (&;$;$)
{
  my $type = ($_[1] && !ref $_[1]) ? $_[1] : '';
  my $ret  = ref $_[1] ? $_[1] : (ref $_[2] ? $_[2] : []);

  unshift @$ret, [$type, $_[0]];
  $ret
}

sub exception2string (;$)
{
  my $ret = ref $_[0] ? $_[0] : [];

  my $s = sub {
    if ($_[0] && (ref $@ && $@->isa('Exceptions::Exception'))){
      $_[0] = $_[0]->msg."\n";
    }
  };
  unshift @$ret, [undef, $s];
  $ret
}

sub string2exception (;$)
{
  my $ret = ref $_[0] ? $_[0] : [];

  my $s = sub {
    if (!ref $_[0]){
      chomp($_[0]);
      $_[0] = Exceptions::Exception->new($_[0]);
    }
  };
  unshift @$ret, [undef, $s];
  $ret
}

sub make_exlist (;$)
{
  my $ret = ref $_[0] ? $_[0] : [];

  my $s = sub {
    return if (ref $_[0] && $_[0]->isa('Exceptions::List'));
    $_[0] = Exceptions::List->new($_[0]);
  };
  unshift @$ret, [undef, $s];
  $ret
}

1;

