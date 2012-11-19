package Exceptions;
use base qw(Exporter);
use Exceptions::Exception;
our @EXPORT;
@EXPORT = qw(try throw catch);

our $VERSION = '0.2.0';

=head1 SYNOPSIS

  use Exceptions;

  try {
    ## do something ##
    ...
    # throw exception of 'Exceptions::Exception' type
    throw 'Exceptions::Exception' => "message";
    ...
    # throw exception of 'MyException' type
    throw MyException => $arg1, $arg2, $arg3;
  }
  catch {
    ## catch exception of 'MyException' type ##
  } 'MyException',
  catch {
    ## catch exception of 'Exceptions::Exception' type ##
    my $msg = $_[0]->msg;    ##< obtain message from exception
  } 'Exceptions::Exception',
  catch {
    ## catch all exceptions ##
  };

=cut

sub throw
{
  die $_[0] if ref $_[0];
  die +(shift)->new(@_);
}

sub try (&;$)
{
  my $ret = eval { &{$_[0]} };
  if ($@){
    my $arr = $_[1];
    if ($arr){
      while (@$arr){
        my ($t, $s) = @{ shift @$arr };
        return &$s($@) if (!$t || $@->isa($t));
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

1;

