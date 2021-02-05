package Task::ID;
use File::Spec::Functions qw(splitdir);
use Exceptions;
use Exporter 'import';
use overload '""' => sub { $_[0]->id };

BEGIN {
  if (!exists &legacy) {
    my $v = $^V < 5.018;
    *legacy = sub () { $v }
  }
}
BEGIN{*m_parse_value = legacy ? *m_parse_value_old : *m_parse_value_re}
BEGIN{*reset = legacy ? *m_reset_old : *m_reset}

our @EXPORT_OK = qw(
  arg2str
);

sub new
{
  my $class = shift;

  my $self = bless {
    # example:
    # short_id => 'a/path/task_name', #corresponding file a/path/task_name.conf
    # basename => 'task_name',        #corresponding file a/path/task_name.conf
    # dirs  => ['a', 'path'],         #corresponding file a/path/task_name.conf
    # id => 'a/path/task_name:arg1=value1,arg2=e1 e2',
    # args => {'' => {arg1 => ['value1'], arg2=['e1', 'e2']}},
    # args_str => 'arg1=value1,arg2=e1 e2',
  }, $class;
  $self->reset(@_);
  $self
}

sub short_id { $_[0]{short_id} }
sub basename { $_[0]{basename} }
sub dirs { @{$_[0]{dirs}} }
sub id { $_[0]{id} }
sub has_args { !!%{$_[0]{args}} }
# my %args = $tid->args; #< ('gr_1' => {arg1 => ['elm 1',...],...},...)
sub args { %{$_[0]{args}} }
sub args_str { $_[0]{args_str} }

# my $arg_str = arg2str($gr, $var, @value);
# $gr  may be undef => prefix 'gr::' will be ommitted.
# $var may be undef => prefix 'gr::var=' will be ommited.
sub arg2str
{
  my $gr = shift;
  my $var = shift;

  my $ret = '';
  if (defined $var) {
    $ret = $gr.'::' if defined $gr;
    $ret .= $var.'=';
  }
  $ret.join ' ', map {
    my $v = $_;
    $v =~ s/([\\ \$'",])/\\$1/g;
    $v =~ s/\n/\\n/g;
    $v =~ s/\t/\\t/g;
    $v
  } @_
}

sub m_reset
{
  my ($self, $s) = @_;
  my ($sid, %args);

  my ($vg, $vn);
  my $var_name = qr<(\w++)(?{$vn = $^N})>;
  my $var_group = qr<(\w*)::(?{$vg = $^N})|(?{$vg = ''})>;
  my $var = qr<$var_group$var_name>;
  my $arg = qr<\s*+$var\s*+=\s*+
    (
      (?:
        \\. |
        [^\\,'"]++ |
        '(?:[^\\']++|\\.)*+' |
        "(?:[^\\"]++|\\.)*+"
      )*+
    )
    (?{
      $args{$vg}{$vn} = [$^N];
    })
  >x;
  if (!($s =~ /^\s*([^:]+?)(?:\.conf)? \s* (?: :(?:$arg(?:,$arg)*+)? )?$/x)) {
    throw Exception => "wrong task specification '$s'";
  }
  my $short_id = $1;
  while (my ($g, $cnt) = each %args) {
    while (my ($v, $val) = each %$cnt) {
      $args{$g}{$v} = [m_parse_value($val->[0])];
    }
  }
  $self->{short_id} = $short_id;
  $self->{id} = $short_id;
  my $args_str = join ',', map {
    my $gr = $_;
    join ',', map {
      my $val = $args{$gr}{$_};
      "${gr}::$_=".join ' ', map {
        my $v = $_;
        $v =~ s/([\\ \$'",])/\\$1/g;
        $v =~ s/\n/\\n/g;
        $v =~ s/\t/\\t/g;
        $v
      } @$val
    } sort keys %{$args{$gr}}
  } sort keys %args;
  $self->{id} .= ':'.$args_str if $args_str;
  $self->{args} = \%args;
  $self->{args_str} = $args_str;
  my @dirs = splitdir($short_id);
  $self->{basename} = pop @dirs;
  $self->{dirs} = \@dirs;
}

sub m_reset_old
{
  local our ($vg, $vn, %args);
  my ($self, $s) = @_;
  my $sid;
  use re 'eval';

  my ($vg, $vn);
  my $var_name = qr<(\w++)(?{$vn = $^N})>;
  my $var_group = qr<(\w*)::(?{$vg = $^N})|(?{$vg = ''})>;
  my $var = qr<$var_group$var_name>;
  my $arg = qr<\s*+$var\s*+=\s*+
    (
      (?:
        \\. |
        [^\\,'"]++ |
        '(?:[^\\']++|\\.)*+' |
        "(?:[^\\"]++|\\.)*+"
      )*+
    )
    (?{
      $args{$vg}{$vn} = [$^N];
    })
  >x;
  if (!($s =~ /^\s*([^:]+?)(?:\.conf)? \s* (?: :(?:$arg(?:,$arg)*+)? )?$/x)) {
    throw Exception => "wrong task specification '$s'";
  }
  my $short_id = $1;
  while (my ($g, $cnt) = each %args) {
    while (my ($v, $val) = each %$cnt) {
      $args{$g}{$v} = [m_parse_value($val->[0])];
    }
  }
  $self->{short_id} = $short_id;
  $self->{id} = $short_id;
  my $args_str = join ',', map {
    my $gr = $_;
    join ',', map {
      my $val = $args{$gr}{$_};
      "${gr}::$_=".join ' ', map {
        my $v = $_;
        $v =~ s/([\\ \$'",])/\\$1/g;
        $v =~ s/\n/\\n/g;
        $v =~ s/\t/\\t/g;
        $v
      } @$val
    } sort keys %{$args{$gr}}
  } sort keys %args;
  $self->{id} .= ':'.$args_str if $args_str;
  $self->{args} = \%args;
  $self->{args_str} = $args_str;
  my @dirs = splitdir($short_id);
  $self->{basename} = pop @dirs;
  $self->{dirs} = \@dirs;
}

sub m_parse_value_re
{
  my $val_str = shift;
  my @ret;

  my $do_concat = 0;
  my $add_word = sub { $do_concat ? $ret[-1] .= $_[0] : push @ret, $_[0]; $do_concat = 1 };

  my $interpolate_str = sub {
    my $str = shift;
    $str =~ s/\\(n)|\\(t)|\\(.)/$1 ? "\n" : $2 ? "\t" : $3/ge;
    $str
  };
  my $normalize_str = sub {
    my $str = shift;
    $str =~ s/\\([\\\$'" \t])/$1/g;
    $str
  };
  my $space = qr~(?:\s++|#.*|\r?\n)\r?\n?(?{ $do_concat = 0 })~s;
  my $normal_word = qr~((?:[^\\\'"# \t\n]|\\(?:.|$))++)(?{ &$add_word(&$interpolate_str($^N)) })~s;
  my $q_str  = qr~'((?:[^\\']|\\.)*+)'(?{ &$add_word(&$normalize_str($^N)) })~s;
  my $qq_str = qr~"((?:[^\\"]|\\.)*+)"(?{ &$add_word(&$interpolate_str($^N)) })~s;
  my $value = qr<^(?:$space|$normal_word|$q_str|$qq_str)*+$>;
  $val_str =~ /$value/ or throw Exception => "syntax error in string '$val_str'";
  @ret
}

sub m_parse_value_old
{
  my $val_str = shift;
  my @ret;
  my $do_concat = 0;
  my $add_word = sub { $do_concat ? $ret[-1] .= $_[0] : push @ret, $_[0]; $do_concat = 1 };
  local $_ = $val_str;
  while ($_ ne '') {
    if (s/(?:\s++|#.*|\r?\n)\r?\n?//s) {
      # space
      $do_concat = 0;
    }
    elsif (s/((?:[^\\\'"# \t\n]|\\(?:.|$))++)//s) {
      # normal word
      &$add_word(m_interpolate_str($1));
    }
    elsif (s/'((?:[^\\']|\\.)*+)'//s) {
      # q_str
      &$add_word(m_normalize_str($1));
    }
    elsif (s/"((?:[^\\"]|\\.)*+)"//s) {
      # qq_str
      &$add_word(m_interpolate_str($1));
    }
    else {
      throw Exception => "syntax error in string '$val_str'"
    }
  }
  @ret
}

sub m_interpolate_str
{
  my $str = shift;
  $str =~ s/\\(n)|\\(t)|\\(.)/$1 ? "\n" : $2 ? "\t" : $3/ge;
  $str
}

sub m_normalize_str
{
  my $str = shift;
  $str =~ s/\\([\\\$'" \t])/$1/g;
  $str
}

1
