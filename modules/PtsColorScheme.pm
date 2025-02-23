package PtsColorScheme;
use MyConsoleColors qw(:ALL_COLORS %current_color);
use Exporter qw(import);

our %COLOR_SCHEME;

BEGIN {
  %COLOR_SCHEME = (
    dbg     => cyan,
    code    => br_yellow,
    comment => yellow,
    italic  => br_blue,
    bold    => br_magenta,
  );
}

our @EXPORT_OK = qw(
  clr_end
  clr_dbg
  clr_code
  clr_comment
  clr_italic
  clr_bold
  color_ref
);
our @EXPORT = @EXPORT_OK;

sub update_constants
{
  for (keys %COLOR_SCHEME) {
    *{"clr_$_"} = *{"MyConsoleColors::clr_$COLOR_SCHEME{$_}"};
  }
  *clr_end = *MyConsoleColors::clr_end;
}

BEGIN {
  update_constants;
}

# *color = color_ref('color_name');
sub color_ref
{
  my $clr = shift;
  return \$current_color{$COLOR_SCHEME{$clr}} if exists $COLOR_SCHEME{$clr};
  return \$current_color{$clr} if exists $current_color{$clr};
  undef
}

sub import
{
  update_constants if clr_end ne &MyConsoleColors::clr_end;
  goto &Exporter::import;
}

1

__END__

=head1 SYNOPSIS

  use PtsColorScheme;
  my ($ci, $cc, $ce) = (clr_italic, clr_code, clr_end);

  print "To print ${ci}colored$ce text write this code: ${cc}use PtsColorScheme;$ce\n";

  ###########################################

  use PtsColorScheme;
  our ($ci, $cc, $ce);
  *ci = color_ref('italic');
  *cc = color_ref('code');
  *ce = color_ref('end');

  enable_colors;
  say $ci, "a colored string", $ce;
  enable_colors(0);
  say $ci, "an uncolored string", $ce;

=head1 FUNCTIONS

=over

=item *color = color_ref('color_name')

It returns the reference to the scalar containing the color string when colors enabled.
When colors disabled it returns the empty string.

=back

=head1 CONSTANTS

=over

=item clr_dbg

The color used for debug messages.

=item clr_code

The color used for code blocks.

=item clr_comment

The color used for comments.

=item clr_italic

The color used to mention something.

=item clr_bold

The color used to highlight something.

=back

=head1 SEE ALSO

=over

=item L<MyConsoleColors>

=back

=cut
