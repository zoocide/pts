package Exceptions;
use 5.00008;
use base qw(Exporter);
use Exceptions::Exception;
use Exceptions::List;
use Carp;
our @EXPORT;
@EXPORT = qw(try throw catch exception2string string2exception make_exlist);

our $VERSION = '0.3.2';

=head1 NAME

Exceptions - Another implementation of exceptions.

=head1 SYNOPSIS

  use Exceptions;

  #------------------#
  try{
    try{
      die "ERROR\n";
    }
    catch{
      print "catch 1\n";
    } 'Exception';

    print "skipped\n";
  }
  catch{
    print "catch 2\n";
  };

  # output: |catch 2

  #------------------#
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
  } 'MyException',
  catch {
    ## catch exception of 'Exceptions::Exception' type ##
    my $msg = $_[0]->msg;    ##< obtain message from exception
  } 'Exception',
  catch {
    ## catch all other exceptions ##
  };

  #------------------#
  try{
    ## do something ##
  }
  exception2string   ##< convert Exceptions::Exception object to string exception.
  catch{
    print $_[0];     ##< all exceptions prints normally
  };

  #------------------#
  try{
    die "ERROR occured\n";
  }
  string2exception
  catch{
    ## catch ERROR ##
  } 'Exception';

  #------------------#
  try{
    die "can`t open file\n";
  }
  string2exception  # convert strings to Exceptions::Exception
  make_exlist       # if $@ is not an Exceptions::List, then $@ = Exceptions::List->new($@)
  catch{
    ## now $@ is array of exceptions ##
    unshift @{$@}, Exceptions::Exception->new("cannot proceed:");
      # print $@    =>  |cannot proceed:
      #                 |can`t open file

    throw         # die $@
  } 'List';

=cut

sub throw
{
  croak $@  if !@_;
  die $_[0] if ref $_[0];
  die +('Exceptions::'.(shift))->new(@_);
}

sub try (&;$)
{
  my $ret = eval { &{$_[0]} };
  if (my $e = $@){
    my $arr = $_[1]; #< 'catch' or other subroutines
    my $ret_sub;
    if ($arr){
      # $arr = [ [$type, $subroutine], ...]
      while (@$arr){
        my ($t, $s) = @{ shift @$arr };
        if (!defined $t){ # for modification subroutines $type = undef
          &$s($e);
          next;
        }
        $ret_sub = $s, last if (!$t || eval{ref $e && $e->isa($t)});
      }
      if ($ret_sub){
        $@ = $e;
        my $res = &$ret_sub($e);
        undef $@;
        return $res;
      }
    }
    die $e;
  }
  $ret
}

sub catch (&;$;$)
{
  my $type = ($_[1] && !ref $_[1]) ? $_[1] : '';
  my $ret  = ref $_[1] ? $_[1] : (ref $_[2] ? $_[2] : []);

  $type = 'Exceptions::'.$type if $type && index $type, 'Exceptions::';

  unshift @$ret, [$type, $_[0]];
  $ret
}

sub exception2string (;$)
{
  my $ret = ref $_[0] ? $_[0] : [];

  my $s = sub {
    if ($_[0] && eval{ref $_[0] && $_[0]->isa('Exceptions::Exception')}){
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
    return if eval{ref $_[0] && $_[0]->isa('Exceptions::List')};
    $_[0] = Exceptions::List->new($_[0]);
  };
  unshift @$ret, [undef, $s];
  $ret
}

1;
__END__

=head1 METHODS

=over

=item try(&;$)

'try' executes the block. When exception raised in the block:
If exists 'catch' with suitable argument it is used. Otherwise exception will be forwarded.

=item throw

  DEPRECATED: throw; - forward exception.
  throw 'Exception' => @arguments; - raise new exception object.
  throw $exc_obj; - raise existing exception object.

=item catch

Use it only as exception processor.
  catch {}; - catch exception of any type including string exceptions.
  catch {} 'MyException'; - catch only exception of 'Exceptions::MyException' type.
  DEPRECATED: catch {} 'Exceptions::MyException'; - catch only exception of 'Exceptions::MyException' type.

=item exception2string

Use it only as exception processor.
Converts any 'Exceptions::Exception' object to string exception.

=item string2exception

Use it only as exception processor.
Converts any exception string to exception object 'Exceptions::Exception'.

=make_exlist

Use it only as exception processor.
If exception is not of type 'Exceptions::List' then create new 'Exceptions::List' contained caught exception.

=back

=head1 EXPORT

  try
  throw
  catch
  exception2string
  string2exception
  make_exlist

=head1 AUTHOR

  Alexander Smirnov <zoocide@gmail.com>

=cut

