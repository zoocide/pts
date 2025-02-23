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
    enable_colors
    color_ref
    color_str
    colors_enabled
    %current_color
  ),
);
our %EXPORT_TAGS = (
  ALL_COLORS => \@all,
);

our %COLORS;
our %current_color;
BEGIN {
  %COLORS = (
    end    => "\e[m",
    black  => "\e[30m",
    red    => "\e[31m",
    green  => "\e[32m",
    yellow => "\e[33m",
    blue   => "\e[34m",
    magenta=> "\e[35m",
    cyan   => "\e[36m",
    white  => "\e[37m",
    bg_black  => "\e[40m",
    bg_red    => "\e[41m",
    bg_green  => "\e[42m",
    bg_yellow => "\e[43m",
    bg_blue   => "\e[44m",
    bg_magenta=> "\e[45m",
    bg_cyan   => "\e[46m",
    bg_white  => "\e[47m",
    br_red    => "\e[91m",
    gray      => "\e[90m",
    br_green  => "\e[92m",
    br_yellow => "\e[93m",
    br_blue   => "\e[94m",
    br_magenta=> "\e[95m",
    br_cyan   => "\e[96m",
    br_white  => "\e[97m",
  );
}

sub enable_colors
{
  my $enabled = @_ ? !!shift : 1;
  our $colors_enabled;
  my $ret = 1;
  if ($enabled && $^O eq 'MSWin32') {
    $enabled = !!eval{ require Win32::Console::ANSI };
    if (!$enabled) {
      $ret = 0;
      *use_colors = sub () { 0 };
    }
  }
  return $ret if defined $colors_enabled && $enabled == $colors_enabled;
  for (keys %COLORS) {
    my $v = $enabled ? $COLORS{$_} : '';
    undef *{"clr_$_"} if defined *{"clr_$_"};
    *{"clr_$_"} = sub () { $v };
    $current_color{$_} = $v;
  }
  $colors_enabled = $enabled;
  $ret
}

BEGIN {
  if (!exists &use_colors) {
    my $v = -t STDOUT;
    *use_colors = sub () { $v }
  }
}

BEGIN {
  enable_colors(use_colors);
}

sub color_str
{
  my ($str, $color) = @_;
  $str =~ s/(\e\[m)/$1$color/g;
  my $ce = &clr_end;
  # Place the color end mark before the ending spaces. To work normally with the `die` function.
  $str =~ s/(\s*$)/$ce$1/;
  $color.$str
}

sub colors_enabled ()
{
  our $colors_enabled;
  $colors_enabled
}

sub color_ref
{
  my $clr = shift;
  return \$current_color{$clr} if exists $current_color{$clr};
  undef
}

1

__END__

=head1 SYNOPSIS

  use MyConsoleColors qw(:ALL_COLORS);

  say clr_green."hello, world!".clr_end;

  ######################################

  use MyConsoleColors qw(:ALL_COLORS color_str);

  my ($cgr, $ce) = (clr_green, clr_end);
  print color_str("A ${cgr}multi$ce line\n colored text.\n", clr_yellow);

  ######################################

  use MyConsoleColors qw(enable_colors color_ref);
  our ($cb, $ce);
  *cb = color_ref('green');
  *ce = color_ref('end');

  say $cb, "# A colored comment", $ce;
  enable_colors(0);
  say $cb, "# An uncolored comment", $ce;

=head1 VARIABLES

=over

=item %current_color

The hash contains the color string for each color name.

=back

=head1 FUNCTIONS

=over

=item *color = color_ref('color')

It returns the reference to the scalar containing the color string when colors enabled.
When colors disabled it returns the empty string.

=item $out_str = color_str($in_str, $color)

It returns the I<$in_str> painted with the I<$color>.
The colored parts of I<$in_str> do not change the color.

=item $bool = enable_colors($bool)

It resets the colors constants to enable or disables colors.
Beware, constans inside your compiled script still unchanged due to the stage of constants substitution.

=item $bool = colors_enabled()

It returns the current state of colors in runtime.

=back

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
