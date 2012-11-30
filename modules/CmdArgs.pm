package CmdArgs;
use strict;
use warnings;
use Exceptions;
use Exceptions::InternalError;

use Carp;

our $VERSION = '0.2.1';

=head1 SYNOPSIS

  NOTE: restrictions are not implemented yet!!!

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
    use_cases => { main => ['OPTIONS arg', 'description...'] },
    options => { verbose => ['-v --verbose', 'print more information'], }
  );

=cut

sub arg { $_[0]{parsed}{args}{$_[1]} }
sub opt { $_[0]{parsed}{options}{$_[1]} }
sub is_opt { exists $_[0]{parsed}{options}{$_[1]} }
sub args { %{$_[0]{parsed}{args}} }
sub opts { %{$_[0]{parsed}{options}} }
sub use_case { $_[0]{parsed}{use_case} }

# throws: string, Exceptions::Exception
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
    $h{$sect} || throw Exception => "wrong $sect specification";
    $self->$func($h{$sect});
    delete $h{$sect};
  }

  scalar keys %h == 0 || throw Exception => 'unknown options: '.join(', ', keys %h);
}

# throws: Exceptions::List
sub parse
{
  my $self = shift;

  ## initialize ##
  $self->{parsed} = { options => {}, args => {}, args_arr => [] };
  $self->{options_end} = 0;

  ## obtain @args array ##
  my @args = @_ ? split(/\s+/, $_[0]) : @ARGV;

  ## parse ##
  try{
    my @wrp_iters = map { [$_, [$self->{use_cases}{$_}{sequence}, []]] }
                        keys %{$self->{use_cases}};
    while (@args && @wrp_iters){
      my $atom = $self->m_get_atom(\@args);
      @wrp_iters = map {
        my $u = $_->[0];
        map [$u, $_], $self->m_fwd_iter($atom, $_->[1])
      } @wrp_iters;
      @wrp_iters || throw Exception => 'wrong '.(  $atom->[0] eq 'opt' ? 'option' : 'argument')
                                               ." '$atom->[1]'";
    }
    @wrp_iters = map {
      my $u = $_->[0];
      map [$u, $_], $self->m_fwd_iter(['end'], $_->[1])
    } @wrp_iters;
    $#wrp_iters < 0 && throw Exception => 'wrong arguments';
    $#wrp_iters > 0 && throw Exception => 'internal error: more then one use cases are suitable';
    $self->m_set_arg_names($wrp_iters[0][1]);
    $self->{parsed}{use_case} = $wrp_iters[0][0];
  }
  catch{ throw } 'Exceptions::CmdArgsInfo',
  make_exlist
  catch{
    push @{$@}, Exceptions::CmdArgsInfo->new($self->m_usage_message);
    throw;
  };
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

# throws: -
sub m_init_defaults
{
  my $self = shift;
  $self->{keys}{'--help'}    = 'HELP';
  $self->{keys}{'--version'} = 'VERSION';
  $self->{options}{HELP}    = { keys  => ['--help'   ], type  => undef, descr => 'print help' };
  $self->{options}{VERSION} = { keys  => ['--version'], type  => undef, descr => 'print version' };
  $self->{groups}{OPTIONS}  = [qw(HELP VERSION)];
  $self->{use_cases}{main} = { use_case => 'OPTIONS args...',
                               sequence => [['group', 'OPTIONS'],
                                           [['arg','args','','','...'],
                                           []]],
                               descr => ''};
}

# throws: Exceptions::Exception
sub m_options
{
  my ($self, $opts) = @_;

  ref $opts eq 'HASH' || throw Exception => 'wrong options specification: hash should be used';

  while (my ($name, $val) = each %$opts){
    $self->{options}{$name} = $self->m_option($name, $val);
  }

  @{$self->{groups}{OPTIONS}} = keys %{$self->{options}};
}

# throws: Exceptions::Exception
sub m_groups
{
  my ($self, $groups) = @_;

  ## check correctness of the specification ##
  ref $groups eq 'HASH' || throw Exception => 'wrong groups specification: hash should be used';

  while (my ($name, $opts) = each %$groups){
    ref $opts eq 'ARRAY' || throw Exception => "worng group '$name' specification: "
                                              .'group is an array of options';

    foreach (@$opts){
      exists $self->{options}{$_}
        || throw Exception => "unknown option '$_' specified for group '$name'";
    }
  }

  ## add groups ##
  $self->{groups} = $groups;
}

# throws: Exceptions::Exception
sub m_use_cases
{
  my ($self, $use_cases) = @_;

  # remove default main use_case
  delete $self->{use_cases}{main};

  ref $use_cases eq 'HASH'
    || throw Exception => 'wrong use cases specification: hash should be used';

  while (my ($name, $val) = each %$use_cases){
    $self->{use_cases}{$name} = $self->m_use_case($name, $val);
  }
}

# throws: Exceptions::Exception
sub m_restrictions
{
  my ($self, $restrs) = @_;

  ## unpack restrictions ##
  my @res;
  ref $restrs eq 'ARRAY'
    || throw Exception => 'wrong restrictions specification: array must be used';
  for (@$restrs){
    my @opts = split /|/;
    for (@opts){
      exists $self->{options}{$_}
        || throw Exception => "unknow option '$_' is specified in restriction";
    }
    push @res, [@opts];
  }

  ## add restrictions ##
  $self->{restrictions} = [@res];
}

# on result:
#   $self->{keys}{@keys_of_option} = $option_name
#   return { keys  => [@keys_of_option],
#            type  => $type_of_the_first_key,
#            descr => $opt_value->[1] }
# throws: Exceptions::Exception
sub m_option
{
  my ($self, $name, $opt_value) = @_;

  ## unpack $opt_value ##
  $#$opt_value < 0 && throw Exception => "wrong option '$name' specification";
  my @keys  = split /\s+/, $opt_value->[0];
  $#keys < 0 && throw Exception => "no keys specified for option '$name'";

  ## parse the first key ##
  my $type = undef;
  if ($keys[0] =~ /(.*?):(.*)/){
    $keys[0] = $1;
    $type = $2;
    $self->m_check_type($type);
  }

  ## check all keys ##
  foreach (@keys){
    /[^\w_-]/ && throw Exception => "worong option '$name' specification: '$_'";
    exists $self->{keys}{$_} && throw Exception => "key '$_' duplicate";
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

# throws: Exceptions::Exception
sub m_use_case
{
  my ($self, $name, $use_case) = @_;

  ## unpack $use_case ##
  ref $use_case eq 'ARRAY' || throw Exception => "wrong use case '$name' specification: "
                                                .'array should be used';
  $#$use_case < 0 && throw Exception => "worng use case '$name' specification: "
                                       .'use case sequence is not specified';
  my @seq = split /\s+/, $use_case->[0];

  ## parse sequence ##
  for my $i (0..$#seq){
    my $w = $seq[$i];
    if (exists $self->{groups}{$w}){
    ## options group ##
      $seq[$i] = ['group', $w]; #< [type, group_name]
    }
    elsif ($w =~ /^(\w+)(:(.*?))?(\.\.\.)?(\?)?$/){
      my ($n, $t, $mult, $q) = ($1, $3, $4, $5);
      if (exists $self->{options}{$n}){
      ## mandatory option ##
        ($t || $mult) && throw Exception => "wrong use case '$name' specification: "
                                           ."syntax error in option '$n' specification";
        $seq[$i] = ['mopt', $n, $q]; #< [type, option_name, can_absent]
      }
      else{
      ## argument ##
        $self->m_check_type($t);
        $seq[$i] = ['arg', $n, $t, $q, $mult]; #<[type, arg_name, arg_type, can_absent, array]
      }
    }
    else{
      throw Exception => "wrong use case '$name' spceification: syntax error in '$w'";
    }
  }

  my $p_seq = [];
  $p_seq = m_p_add($p_seq, $seq[-$_]) for 1..@seq;

  ## return new use_case ##
  my $ret = {
    use_case => $use_case->[0],
    sequence => $p_seq,
    descr    => $#$use_case > 0 ? $use_case->[1] : '',
  };
  $ret
}

# throws: Exceptions::Exception
sub m_check_type
{
  my ($self, $type) = @_;
  eval{ "CmdArgs::Types::$type"->can('check') || die };
  $@ && throw Exception => "wrong type specified '$type'";
}

# throws: Exceptions::Exception, ...
sub m_check_arg
{
  my ($self, $arg, $type) = @_;
  !$type || "CmdArgs::Types::$type"->check($arg) || throw Exception => "'$arg' is not $type";
}

# throws: Exceptions::Exception, Exceptions::CmdArgsInfo, ...
sub m_get_atom
{
  my ($self, $args) = @_;

  @$args || return 0;
  my $cur = shift @$args;

  if (!$self->{options_end} && (substr($cur,0,1) eq '-' || exists $self->{keys}{$cur}))
  {
  ## option ##
    if ($cur eq '--'){
    # case '--' #
      $self->{options_end} = 1; ##< enable arguments only mode
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
    exists $self->{keys}{$cur} || throw Exception => "unknown option '$cur'";
    my $opt = $self->{keys}{$cur};
    my $param = 1;
    if (defined $self->{options}{$opt}{type}){
    # option with parameter #
      my $type = $self->{options}{$opt}{type};
      @$args || throw Exception => "parameter for option '$cur' is not specified";
      $param = shift @$args;
      $add_sub = 0;
      $self->m_check_arg($param, $type)
        || throw Exception => "wrong parameter '$param' for option '$cur'";
    }
    $self->{parsed}{options}{$opt} = $param;
    $args->[0] = '-'.$args->[0] if $add_sub;

    $opt eq 'HELP'    && throw CmdArgsInfo => $self->m_help_message;
    $opt eq 'VERSION' && throw CmdArgsInfo => $self->m_version_message;

    return ['opt', $opt];
  }

  ## get argument ##
  push @{$self->{parsed}{args_arr}}, $cur;
  ['arg', $cur]
}

# iter: [sequence, parsed_arguments]
# sequence         = [] | [elm1, []] | [elm1, [elm2, []]] | ...
# parsed_arguments = [] | [arg1, []] | [arg1, [arg2, []]] | ...
# returns: (@fwd_iters)
# throws: Exceptions::Exception, Exceptions::InternalError
sub m_fwd_iter
{
  my ($self, $atom, $iter) = @_;
  my @ret;

  if ($atom->[0] eq 'opt'){
  # option #
    for(my $seq = $iter->[0]; !m_is_p_empty($seq); m_move_next_p($seq)){
      my $cur = m_value_p($seq);
      if    ($cur->[0] eq 'group'){
        if (grep $atom->[1] eq $_, @{$self->{groups}{$cur->[1]}}){
        # group contains current option
          push @ret, [$seq, $iter->[1]];
        }
        next;
      }
      elsif ($cur->[0] eq 'mopt'){
        push @ret, [m_get_next_p($seq), $iter->[1]] if $atom->[1] eq $cur->[1];
        next if $cur->[2]; #< '?' is present
        last;
      }
      elsif ($cur->[0] eq 'arg'){
        next if $cur->[3]; #< '?' is present
        last;
      }
      else{
        throw InternalError => "wrong type '$cur->[0]' of sequence";
      }
    }
  }
  elsif ($atom->[0] eq 'arg'){
  # argument #
    for(my $seq = $iter->[0]; !m_is_p_empty($seq); m_move_next_p($seq)){
      my $cur = m_value_p($seq);
      if    ($cur->[0] eq 'group'){
        next;
      }
      elsif ($cur->[0] eq 'mopt'){
        next if $cur->[2]; #< '?' is present
        last;
      }
      elsif ($cur->[0] eq 'arg'){
        my $present = !m_is_p_empty($iter->[1]) && m_value_p($iter->[1]) eq $cur->[1];
        if (!$cur->[2] || eval{$self->m_check_arg($atom->[1], $cur->[2])}){
          push @ret, [$cur->[4] ? $seq : m_get_next_p($seq), m_p_add($iter->[1], $cur)];
        }
        elsif($cur->[2] && $@){
          # m_check_arg failed
          #
          # INSERT MESSAGE PROCESSING HERE
          #
        }
        next if $cur->[3] || ($cur->[4] && $present);
        last;
      }
      else{
        throw InternalError => "wrong type '$cur->[0]' of sequence";
      }
    }
  }
  elsif ($atom->[0] eq 'end'){
  # end of parse #
    m_is_iter_empty($iter) && return $iter;
    for(my $seq = $iter->[0]; !m_is_p_empty($seq); m_move_next_p($seq)){
      my $cur = m_value_p($seq);
      if    ($cur->[0] eq 'group'){
        next;
      }
      elsif ($cur->[0] eq 'mopt'){
        next if $cur->[2]; #< '?' is present
        return ();
      }
      elsif ($cur->[0] eq 'arg'){
        my $present = !m_is_p_empty($iter->[1]) && m_value_p($iter->[1]) eq $cur->[1];
        next if $cur->[3] || ($cur->[4] && $present);
        return ();
      }
      else{
        throw InternalError => "wrong type '$cur->[0]' of sequence";
      }
    }
    return [[], $iter->[1]]; #< return empty sequence
  }
  else{
    throw InternalError => "wrong atom type ($atom->[0])";
  }

  @ret
}

sub m_is_p_empty  { @{$_[0]} == 0 }                   #< $bool = m_is_p_empty($p);
sub m_move_next_p { $_[0] = $_[0][1] }                #< m_move_next_p($p);
sub m_get_next_p  { $_[0][1] }                        #< $next = m_get_next_p($p);
sub m_value_p     { $_[0][0] }                        #< $value = m_value_p($p);
sub m_p_add       { [$_[1], $_[0]] }                  #< $new_p = m_p_add($p, $value)

# m_dbg($condition, caller_depth);
sub m_dbg
{
  if ($_[0]){
    my (undef, $cf, $cl) = caller;
    my (undef, $f, $l) = caller($_[1]);
    print "DEBUG: assert $cf:$cl. Called from $f:$l\n";
  }
}

sub m_is_iter_empty { @{$_[0][0]} == 0 } #< $bool = m_is_iter_empty($iter);

# throws: Exceptions::Exception
sub m_set_arg_names
{
  my ($self, $iter) = @_;
  my @args = @{$self->{parsed}{args_arr}};
  for (my $p = $iter->[1]; !m_is_p_empty($p); m_move_next_p($p)){
    my $cur = m_value_p($p);
    $cur->[0] eq 'arg' || throw InternalError => "wrong type '$cur->[0]' of arguments sequence";
    if ($cur->[4]){
    # array #
      push @{$self->{parsed}{args}{$cur->[1]}}, pop @args;
    }
    else{
      $self->{parsed}{args}{$cur->[1]} = pop @args;
    }
  }
  @args && throw InternalError => 'parsed arguments mismatch ['.scalar(@args).']';
}


package Exceptions::CmdArgsInfo;
use base qw(Exceptions::Exception);

sub init { (my $self = shift)->SUPER::init(@_); chomp($self->{msg}); }

1;

