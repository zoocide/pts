package Plugins::Base::Util;
use Carp;
use Exporter 'import';

our @EXPORT = qw(
  get_package_dir
);

sub get_package_dir
{
  my $package = shift // caller;
  my $fname = $package;
  $fname =~ s#::#/#g;
  $fname .= '.pm';
  exists $INC{$fname} or croak "Could not find '$package' package";
  my $p = $INC{$fname};
  substr($p, -length $fname) eq $fname || length $p == length $fname
    or croak "An unexpected value occurred for '$package': $INC{$fname}";
  my $dir = substr $p, 0, -1 - length $fname;
  -d $dir or croak "The result found '$dir' is not a directory.";
  $dir
}

1
