package CmdArgs;
use strict;
use base qw(Exporter); # nothing to export

use Carp;

our $VERSION = '0.2.0';

=head1 SYNOPSIS

  use CmdArgs;

  {package CmdArgs::Types::Filename; sub check{my $arg = shift; -f $arg}}

  my $args->declare(
    $version,
    use_cases => { ##< 'main' is the default use case: ['OPTIONS args...', '']
      main   => ['OPTIONS arg1:Filename arg2:Testset', 'the main use case'],
      second => ['OPTS_GROUP_1 arg_1 OPTS_GROUP_2 arg_2', 'the second usage'],
    },
    groups => { ##< 'OPTIONS' is the default group contained all options
      OPTS_GROUP_1 => [qw(opt_1 opt_2 opt_3)],
      OPTS_GROUP_2 => [qw(opt_9 opt_17)],
    },
    options => {
      opt_1  => ['-f:Filename --filename', 'specify filename'],
      opt_2  => ['-i: --input'           , 'specify input filename'],
      opt_3  => ['-s'                    , 'silent mode'],
      opt_9  => ['-z'                    , 'Zzz'],
      opt_17 => ['-0 --none --bla-bla'   , '0. simply 0'],
    },
    restrictions => [
      'opt_1|opt_2|opt_3',
      'opt_1|opt_4',
    ]
  );

  $args->parse;

  ===========================

  $args->parse('string args');

  ===========================

  my $args->declare(
    '0.0.1',
    use_cases => { main => ['OPTIONS arg] },
    options => { verbose => ['-v --verbose', 'print more information'], }
  );

=cut

sub arg { $_[0]{parsed}{args}{$_[1]} }
sub opt { $_[0]{parsed}{options}{$_[1]} }
sub is_opt { exists $_[0]{parsed}{options}{$_[1]} }
sub args { %{$_[0]{parsed}{args}} }
sub opts { %{$_[0]{parsed}{options}} }
sub use_case { $_[0]{parsed}{use_case} }

sub declare
{
  my $class = shift;
  my $self = bless {}, $class;
  eval { $self->init(@_) };
  croak $@ if $@;
  $self
}

sub init
{
  my ($self, $version, %h) = @_;

  ($self->{script_name} = $0) =~ s/.*?[\/\\]//;
  $self->{version} = $version;
  $self->m_init_defaults;

  foreach my $sect (qw(options groups use_cases restrictions)){
    exists $h{$sect} || next;
    my $func = "m_$sect";
    $h{$sect} || die "wrong $sect specification\n";
    $self->$func($h{$sect});
    delete $h{$sect};
  }

  scalar keys %h == 0 || die "unknown options: ".join(', ', keys %h)."\n";
}

sub parse
{
  my $self = shift;

  ## initialize ##
  $self->{parsed} = { options => {}, args => {} };
  $self->{options_end} = 0;

  ## obtain @args array ##
  my @args = @_ ? split(/\s/, $_[0]) : @ARGV;

  ## parse ##
  eval{
    my @iters = map { [$_, [@{$self->{use_cases}{$_}{sequence}}]] } keys %{$self->{use_cases}};
    while (@args && @iters){
      my $atom = $self->m_get_atom(\@args);
      @iters = grep { $self->m_fwd_iter($atom, $_->[1]) } @iters;
      @iters || die "wrong ".($atom->[0] eq 'opt' ? 'option' : 'argument')." '$atom->[1]'\n";
    }
    @iters = grep { $self->m_fwd_iter(['end'], $_->[1]) } @iters;
    $#iters < 0 && die "wrong arguments";
    $#iters > 0 && die "internal error: more then one use cases are suitable\n";
    $self->m_set_arg_names($iters[0][0]);
    $self->{parsed}{use_case} = $iters[0][0];
  };
  if ($@){
    print $@;
    $self->print_usage_and_exit;
  }
}

sub print_help
{
  my $self = shift;
  print $self->m_version_message;
  print $self->m_help_message;
}

sub print_usage_and_exit
{
  my $self = shift;
  print $self->m_usage_message;
  exit -1;
}

sub print_version
{
  my $self = shift;
  print $self->m_version_message;
}



sub m_usage_message
{
  my $self = shift;
  "usage:\n".join '', map "  $self->{script_name} $_->{use_case}\n", values %{$self->{use_cases}};
}

sub m_help_message
{
  my $self = shift;
  my $msg = "usage:\n";
  my @ucs = values %{$self->{use_cases}};
  $msg .= join '', map '  '.($_+1).": $self->{script_name} $ucs[$_]{use_case}\n", 0..$#ucs;
  $msg .= join '', map +($_+1).": $ucs[$_]{descr}\n", 0..$#ucs;
  while (my ($gr_name, $gr_cont) = each %{$self->{groups}}){
    $msg .= "$gr_name:\n";
    for my $opt (map $self->{options}{$_}, @$gr_cont){
      $msg .= "\t".join(' ', @{$opt->{keys}})."\t$opt->{descr}\n";
    }
  }
  $msg
}

sub m_version_message
{
  my $self = shift;
  "version $self->{version}\n";
}

sub m_init_defaults
{
  my $self = shift;
  $self->{keys}{'--help'}    = 'HELP';
  $self->{keys}{'--version'} = 'VERSION';
  $self->{options}{HELP}    = { keys  => ['--help'   ], type  => undef, descr => 'print help' };
  $self->{options}{VERSION} = { keys  => ['--version'], type  => undef, descr => 'print version' };
  $self->{groups}{OPTIONS}  = [qw(HELP VERSION)];
  $self->{use_cases}{main} = { use_case => 'OPTIONS args...', sequence => [['OPTIONS'], 'args+'], descr => ''}
}

sub m_options
{
  my ($self, $opts) = @_;

  ref $opts eq 'HASH' || die "wrong options specification: hash should be used\n";

  while (my ($name, $val) = each %$opts){
    $self->{options}{$name} = $self->m_option($name, $val);
  }

  @{$self->{groups}{OPTIONS}} = keys %{$self->{options}};
}

sub m_groups
{
  my ($self, $groups) = @_;

  ## check correctness of the specification ##
  ref $groups eq 'HASH' || die "wrong groups specification: hash should be used\n";

  while (my ($name, $opts) = each %$groups){
    ref $opts eq 'ARRAY' || die "worng group '$name' specification: group is an array of options\n";

    foreach (@$opts){
      exists $self->{options}{$_} || die "unknown option '$_' specified for group '$name'\n";
    }
  }

  ## add groups ##
  $self->{groups} = $groups;
}

sub m_use_cases
{
  my ($self, $use_cases) = @_;

  # remove default main use_case
  delete $self->{use_cases}{main};

  ref $use_cases eq 'HASH' || die "wrong use cases specification: hash should be used\n";

  while (my ($name, $val) = each %$use_cases){
    $self->{use_cases}{$name} = $self->m_use_case($name, $val);
  }
}

sub m_restrictions
{
  my ($self, $restrs) = @_;

  ## unpack restrictions ##
  my @res;
  ref $restrs eq 'ARRAY' || die "wrong restrictions specification: array must be used\n";
  for (@$restrs){
    my @opts = split /|/;
    for (@opts){
      exists $self->{options}{$_} || die "unknow option '$_' is specified in restriction\n";
    }
    push @res, [@opts];
  }

  ## add restrictions ##
  $self->{restrictions} = [@res];
}

sub m_option
{
  my ($self, $name, $opt_value) = @_;

  ## unpack $opt_value ##
  $#$opt_value < 0 && die "wrong option '$name' specification\n";
  my @keys  = split /\s+/, $opt_value->[0];
  $#keys < 0 && die "no keys specified for option '$name'\n";

  ## parse the first key ##
  my $type = undef;
  if ($keys[0] =~ /(.*?):(.*)/){
    $keys[0] = $1;
    $type = $2;
    $self->m_check_type($type);
  }

  ## check all keys ##
  foreach (@keys){
    /[^\w_-]/ && die "worong option '$name' specification: '$_'\n";
    exists $self->{keys}{$_} && die "key '$_' duplicate\n";
    $self->{keys}{$_} = $name;
  }

  ## return new option ##
  my $ret = {
    keys  => [@keys],
    type  => $type,
    descr => ($#$opt_value > 0 ? $opt_value->[1] : ''),
  };
  $ret
}

sub m_use_case
{
  my ($self, $name, $use_case) = @_;

  ## unpack $use_case ##
  ref $use_case eq 'ARRAY' || die "wrong use case '$name' specification: array should be used\n";
  $#$use_case < 0 && die "worng use case '$name' specification: use case sequence is not specified\n";
  my @seq = split /\s+/, $use_case->[0];

  ## parse sequence ##
  for my $i (0..$#seq){
    my $w = $seq[$i];
    if (exists $self->{groups}{$w}){
      $seq[$i] = [$w];
    }
    elsif ($w =~ /^(\w+)(:(.*?))?(\.\.\.)?(\?)?$/){
      my ($n, $t, $mult, $q) = ($1, ($3 ? $3 : ''), ($4 ? '+' : ''), ($5 ? '?' : ''));
      $self->m_check_type($t);
      $seq[$i] = $n.':'.$t.$mult.$q;
    }
    else{
      die "wrong use case '$name' spceification: syntax error in '$w'\n";
    }
  }

  ## return new use_case ##
  my $ret = {
    use_case => $use_case->[0],
    sequence => [@seq], ##< ([group_name_1], 'name1:type1', [group_name_2], 'name3:+?', 'name4:type3')
    descr    => $#$use_case > 0 ? $use_case->[1] : '',
  };
  $ret
}

sub m_check_type
{
  my ($self, $type) = @_;
}

sub m_check_arg
{
  my ($self, $arg, $type) = @_;
  !$type || "CmdArgs::Types::$type"->check($arg) || die "'$arg' is not $type\n";
}

sub m_get_atom
{
  my ($self, $args) = @_;

  @$args || return 0;
  my $cur = shift @$args;

  if (!$self->{options_end} && (substr($cur,0,1) eq '-' || exists $self->{keys}{$cur}))
  {
    if ($cur eq '--'){
    # case '--' #
      $self->{options_end} = 1;
      return $self->m_get_atom($args);
    }

    ## get option ##
    my $add_sub = 0;
    if ($cur =~ /^\-[^\-]/ && length $cur > 2){
    # split one-char options #
      unshift @$args, substr($cur, 2);
      $add_sub = 1;
      $cur = substr $cur, 0, 2;
    }
    exists $self->{keys}{$cur} || die "unknown option '$cur'\n";
    my $opt = $self->{keys}{$cur};
    my $param = 1;
    if (defined $self->{options}{$opt}{type}){
    # option with parameter #
      my $type = $self->{options}{$opt}{type};
      @$args || die "parameter for option '$cur' is not specified\n";
      $param = shift @$args;
      $add_sub = 0;
      $self->m_check_arg($param, $type);
    }
    $self->{parsed}{options}{$opt} = $param;
    $args->[0] = '-'.$args->[0] if $add_sub;

    if ($opt eq 'HELP'){ $self->print_help; exit; }
    if ($opt eq 'VERSION'){ $self->print_version; exit; }

    return ['opt', $opt];
  }

  ## get argument ##
  push @{$self->{parsed}{args_arr}}, $cur;
  ['arg', $cur]
}

sub m_fwd_iter
{
  my ($self, $atom, $iter) = @_;

  if ($atom->[0] eq 'opt'){
  # option #
    @$iter || return 0;
    my $cur = $iter->[0];
    while (ref $cur){
      (grep {$atom->[1] eq $_} @{$self->{groups}{$cur->[0]}}) && return 1;
      shift @$iter;
      @$iter || return 0;
      $cur = $iter->[0];
    }
    return 0;
  }
  elsif ($atom->[0] eq 'arg'){
  # argument #
    shift @$iter while @$iter && ref $iter->[0];
    @$iter || return 0;
    my $cur = $iter->[0];

    $cur =~ /^(.+?):(.*?)(\+?)(\??)$/ || die "internal error (can`t parse '$cur')";
    my ($name, $type, $rep, $opt) = ($1, $2, $3, $4);
    eval { $self->m_check_arg($atom->[1], $type) };
    $@ && return 0;
    shift @$iter;
  }
  elsif ($atom->[0] eq 'end'){
  # end of parse #
    shift @$iter while @$iter && ref $iter->[0];
    @$iter && return 0;
  }
  else{
    die "internal error: wrong atom type ($atom->[0])";
  }

  1
}

sub m_set_arg_names
{
  my ($self, $use_case) = @_;
  my @names = map { ref $_ ? () : (/(.+?):/ && $1) } @{$self->{use_cases}{$use_case}{sequence}};
  $#names == $#{$self->{parsed}{args_arr}} || die "internal error: can`t set names for arguments";
  $self->{parsed}{args} = { map { ($names[$_], $self->{parsed}{args_arr}[$_]) } 0..$#names };
}

1;

