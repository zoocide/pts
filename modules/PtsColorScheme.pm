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
