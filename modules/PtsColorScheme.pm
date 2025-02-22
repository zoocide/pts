package PtsColorScheme;
use MyConsoleColors qw(:ALL_COLORS);
use Exporter qw(import);

our @EXPORT_OK = qw(
  clr_end
  clr_dbg
  clr_code
  clr_comment
  clr_italic
  clr_bold
);
our @EXPORT = @EXPORT_OK;

use constant {
  clr_dbg => clr_cyan,
  clr_code => clr_br_yellow,
  clr_comment => clr_yellow,
  clr_italic => clr_br_blue,
  clr_bold => clr_br_magenta,
};

1

__END__

=head1 SYNOPSIS

  use PtsColorScheme;
  my ($ci, $cc, $ce) = (clr_italic, clr_code, clr_end);

  print "To print ${ci}colored$ce text write this code: ${cc}use PtsColorScheme;$ce\n";

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
