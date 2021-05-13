package Plugins::Base::Util;
use Carp;
use Cwd;
use Exporter 'import';

our @EXPORT = qw(
  get_package_dir
);

my $cwd = cwd();

sub get_package_dir
{
  my $package = shift // caller;
  my $fname = $package;
  $fname =~ s#::#/#g;
  $fname .= '.pm';
  exists $INC{$fname} or croak "Could not find '$package' package";
  my $p = $INC{$fname};
  return $cwd if length $p == length $fname;
  substr($p, -length $fname) eq $fname
    or croak "An unexpected value occurred for '$package': $INC{$fname}";
  my $dir = substr $p, 0, -1 - length $fname;
  -d $dir or croak "The result found '$dir' is not a directory.";
  $dir
}

1

__END__

=head1 NAME

Plugins::Base::Util - A selection of useful utility functions to write your own plugin for the PTS system.

=head1 FUNCTIONS

=over

=item get_package_dir($package)

Return the directory containing the package I<.pm> file.
By default $package is the caller's __PACKAGE__.
E.g., C<get_package_dir()> returns I</a/lib/path> for the path I</a/lib/path/Plugins/Your/Plugin/Name.pm>.

=back
