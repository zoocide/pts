package CmdArgs::BasicTypes;

package CmdArgs::Types::File;
use Exceptions;

sub check
{
   -e $_[1] or throw Exception => "File '$_[1]' does not exist.";
  !-d $_[1] or throw Exception => "'$_[1]' is a directory."
}


package CmdArgs::Types::Dir;
use Exceptions;

sub check
{
  -d $_[1] or throw Exception => "'$_[1]' is not a directory."
}


package CmdArgs::Types::NotDir;
use Exceptions;

sub check
{
  !-d $_[1] or throw Exception => "'$_[1]' is a directory."
}


package CmdArgs::Types::Int;
use Exceptions;
use Scalar::Util qw(looks_like_number);

sub check
{
  looks_like_number($_[1]) && int($_[1]) == $_[1]
      or throw Exception => "'$_[1]' is not an integer number."
}


package CmdArgs::Types::Real;
use Exceptions;
use Scalar::Util qw(looks_like_number);

sub check
{
  looks_like_number($_[1])
      or throw Exception => "'$_[1]' is not a real number."
}

1

__END__

=head1 NAME

BasicTypes - a set of frequently used general-purpose CmdArgs types
for options and arguments.

=head1 TYPES

=head2 CmdArgs::Types::File

It corresponds to an existing file, which is not a directory.

=head2 CmdArgs::Types::Dir

It corresponds to an existing directory.

=head2 CmdArgs::Types::NotDir

It corresponds to anything, but an existing directory.

=head2 CmdArgs::Types::Int

It corresponds to an integer number.

=head2 CmdArgs::Types::Real

It corresponds to an real number.

=head1 AUTHOR

Alexander Smirnov <zoocide@gmail.com>

=cut
