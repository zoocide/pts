package MyConsoleColors;
use Exporter 'import';

my @fg_colors = qw(
  clr_black
  clr_red
  clr_green
  clr_yellow
  clr_blue
  clr_magenta
  clr_cyan
  clr_white
);
my @bg_colors = qw(
  clr_bg_black
  clr_bg_red
  clr_bg_green
  clr_bg_yellow
  clr_bg_blue
  clr_bg_magenta
  clr_bg_cyan
  clr_bg_white
);
my @br_colors = qw(
  clr_gray
  clr_br_red
  clr_br_green
  clr_br_yellow
  clr_br_blue
  clr_br_magenta
  clr_br_cyan
  clr_br_white
);
my @end = qw(clr_end);
my @all = (
  @end,
  @fg_colors,
  @bg_colors,
  @br_colors,
);

our @EXPORT_OK = (
  @all,
  qw (
    color_str
  ),
);
our %EXPORT_TAGS = (
  ALL_COLORS => \@all,
);

BEGIN{
  if (!exists &use_colors) {
    my $v = -t STDOUT && ($^O ne 'MSWin32' || eval{ require Win32::Console::ANSI });
    *use_colors = sub () { $v }
  }
}

use constant {
  clr_end    => use_colors ? "\e[m" : '',
  clr_black  => use_colors ? "\e[30m" : '',
  clr_red    => use_colors ? "\e[31m" : '',
  clr_green  => use_colors ? "\e[32m" : '',
  clr_yellow => use_colors ? "\e[33m" : '',
  clr_blue   => use_colors ? "\e[34m" : '',
  clr_magenta=> use_colors ? "\e[35m" : '',
  clr_cyan   => use_colors ? "\e[36m" : '',
  clr_white  => use_colors ? "\e[37m" : '',
  clr_bg_black  => use_colors ? "\e[40m" : '',
  clr_bg_red    => use_colors ? "\e[41m" : '',
  clr_bg_green  => use_colors ? "\e[42m" : '',
  clr_bg_yellow => use_colors ? "\e[43m" : '',
  clr_bg_blue   => use_colors ? "\e[44m" : '',
  clr_bg_magenta=> use_colors ? "\e[45m" : '',
  clr_bg_cyan   => use_colors ? "\e[46m" : '',
  clr_bg_white  => use_colors ? "\e[47m" : '',
  clr_gray      => use_colors ? "\e[90m" : '',
  clr_br_red    => use_colors ? "\e[91m" : '',
  clr_br_green  => use_colors ? "\e[92m" : '',
  clr_br_yellow => use_colors ? "\e[93m" : '',
  clr_br_blue   => use_colors ? "\e[94m" : '',
  clr_br_magenta=> use_colors ? "\e[95m" : '',
  clr_br_cyan   => use_colors ? "\e[96m" : '',
  clr_br_white  => use_colors ? "\e[97m" : '',
};

sub color_str
{
  my ($str, $color) = @_;
  $str =~ s/(\e\[m)/$1$color/g;
  my $ce = clr_end;
  # Place the color end mark before the ending spaces. To work normally with the `die` function.
  $str =~ s/(\s*$)/$ce$1/;
  $color.$str
}

1

__END__

=head1 SYNOPSIS

  use MyConsoleColors qw(:ALL_COLORS color_str);

  my ($cgr, $ce) = (clr_green, clr_end);
  print color_str("A ${cgr}multi$ce line\n colored text.\n", clr_yellow);

=head1 CONSTANTS

=head2 Special constants.

=over

=item clr_end

It resets the color to the default.

=back

=head2 Common colors.

=over

=item clr_black

=item clr_red

=item clr_green

=item clr_yellow

=item clr_blue

=item clr_magenta

=item clr_cyan

=item clr_white

=back

=head2 Background colors.

=over

=item clr_bg_black

=item clr_bg_red

=item clr_bg_green

=item clr_bg_yellow

=item clr_bg_blue

=item clr_bg_magenta

=item clr_bg_cyan

=item clr_bg_white

=back

=head2 Bright colors.

=over

=item clr_gray

=item clr_br_red

=item clr_br_green

=item clr_br_yellow

=item clr_br_blue

=item clr_br_magenta

=item clr_br_cyan

=item clr_br_white

=back

=cut
