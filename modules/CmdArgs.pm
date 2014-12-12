package CmdArgs;
use 5.00008;
use strict;
use warnings;
use Exceptions;
use Exceptions::InternalError;

use Carp;

our $VERSION = '0.3.0';

## TODO: Add method 'convert' for types.

=head1 NAME

CmdArgs - Parse command line arguments and automate help message creation.

=head1 SYNOPSIS

  use CmdArgs;

  {package CmdArgs::Types::Filename; sub check{my $arg = $_[1]; -f $arg}}

  my $args = CmdArgs->declare(
    $version,
    ## You can use [] instead of {} if use_cases order is important ##
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
      opt_2  => ['-i:<FILE> --input'     , 'read input from FILE'],
      opt_3  => ['-s'                    , 'silent mode'],
      opt_9  => ['-z'                    , 'Zzz'],
      opt_17 => ['-0 --none --bla-bla'   , '0. simply 0'],
      verbose=> ['-v' , 'more verbose', sub {$verbose++}],
      name => ['-n:', 'set a name', sub {$name = $_}],
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

  ## simple expamle ##
  my $args = CmdArgs->declare(
    '0.1.0',
    use_cases => { main => ['OPTIONS arg', 'description...'] },
    options => { verbose => ['-v --verbose', 'print more information'], }
  );
  $args->parse;

=cut

sub arg { $_[0]{parsed}{args}{$_[1]} }
sub opt { $_[0]{parsed}{options}{$_[1]} }
sub is_opt { exists $_[0]{parsed}{options}{$_[1]} }
sub args { %{$_[0]{parsed}{args}} }
sub opts { %{$_[0]{parsed}{options}} }
sub use_case { $_[0]{parsed}{use_case} }

# throws: string
sub declare
{
  my $class = shift;
  my $self = bless {}, $class;
  eval { $self->init(@_) };
  croak "$@" if $@;
  $self
}

# throws: Exceptions::Exception
sub init
{
  my ($self, $version, %h) = @_;

  ($self->{script_name} = $0) =~ s/.*[\/\\]//;
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
    while (@args){
      my $atom = $self->m_get_atom(\@args);

      ## for error handling ##
      $self->{parse}{failed_arg_checks} = [];

      @wrp_iters = map {
        my $u = $_->[0];
        map [$u, $_], $self->m_fwd_iter($atom, $_->[1])
      } @wrp_iters;

      ## handle errors ##
      if (!@wrp_iters){
        if (@{$self->{parse}{failed_arg_checks}}){
          my @uniq_errors;
          for my $e (@{$self->{parse}{failed_arg_checks}}){
            push @uniq_errors, $e if !grep "$e" eq "$_", @uniq_errors;
          }
          throw List => @uniq_errors;
        }
        throw Exception => 'unexpected '.(  $atom->[0] eq 'opt'
                                        ? "option '$atom->[2]'"
                                        : "argument '$atom->[1]'");
      }
    }
    #TODO: if $#wrp_iters == 0,  say, where it stops.
    # finish with 'end' atom
    @wrp_iters = map {
      my $u = $_->[0];
      map [$u, $_], $self->m_fwd_iter(['end'], $_->[1])
    } @wrp_iters;
    $#wrp_iters < 0 && throw Exception => 'wrong arguments';
    $#wrp_iters > 0 && throw Exception => 'internal error: more then one use cases are suitable';
    $self->{parsed}{use_case} = $wrp_iters[0][0];
    $self->m_set_arg_names($wrp_iters[0][1]);
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



sub m_use_case_msg
{
  my ($self, $uc) = @_;
  my $ret = $self->{script_name};
  for(my $seq = $uc->{sequence}; !m_is_p_empty($seq); m_move_next_p($seq)){
    my $cur = m_value_p($seq);
    if    ($cur->[0] eq 'group'){
      $ret.= ' '.$cur->[1];
    }
    elsif ($cur->[0] eq 'mopt' ){
      my $o = $self->{options}{$cur->[1]};
      my @keys = @{$o->{keys}};
      my $s = join '|', @keys;
      $s  = '('.$s.')'       if @keys > 1;
      $s .= ' '.$o->{arg_name} if defined $o->{type};
      $s  = '['.$s.']'       if $cur->[2];
      $ret.= ' '.$s;
    }
    elsif ($cur->[0] eq 'arg'){
      my $s = $cur->[1];
      $s .= '...'      if $cur->[4];
      $s  = '['.$s.']' if $cur->[3];
      $ret .= ' '.$s;
    }
  }
  $ret
}

sub m_usage_message
{
  my $self = shift;
  my $ret = "usage:\n";
  my @uc_names = exists $self->{arrangement}{use_cases}
               ? @{$self->{arrangement}{use_cases}}
               : keys $self->{use_cases};
  for my $uc_name (@uc_names){
    $ret .= '  '.$self->m_use_case_msg($self->{use_cases}{$uc_name})."\n";
  }
  $ret .= "Try --help option for help.\n";
  $ret
}

sub m_help_message
{
  my $self = shift;
  my $ret = "usage:\n";
  my @uc_names = exists $self->{arrangement}{use_cases}
               ? @{$self->{arrangement}{use_cases}}
               : keys $self->{use_cases};
  my @ucs = map $self->{use_cases}{$_}, @uc_names;
  if (@ucs == 1){
    # do not print number before use case
    $ret .= '  '.$self->m_use_case_msg($ucs[0])."\n";
    $ret .= "$ucs[0]{descr}\n";
  }
  else{
    $ret .= join '', map '  '.($_+1).': '.$self->m_use_case_msg($ucs[$_])."\n", 0..$#ucs;
    $ret .= join '', map +($_+1).": $ucs[$_]{descr}\n", 0..$#ucs;
  }
  while (my ($gr_name, $gr_cont) = each %{$self->{groups}}){
    $ret .= "$gr_name:\n";
    for my $opt (map $self->{options}{$_}, @$gr_cont){
      next if !defined $opt->{descr};
      $ret .= "\t".join(', ', @{$opt->{keys}});
      $ret .= " $opt->{arg_name}" if defined $opt->{type};
      $ret .= "\t$opt->{descr}\n";
    }
  }
  $ret
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
  $self->{arrangement}{first_keys}{'--help'} = 'HELP';
  $self->{arrangement}{first_keys}{'--version'} = 'VERSION';
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

  ## arrange options by the first key ##
  my @fkeys = sort keys $self->{arrangement}{first_keys};
  @{$self->{groups}{OPTIONS}} = map $self->{arrangement}{first_keys}{$_}, @fkeys;
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

  if (ref $use_cases eq 'ARRAY'){
    $self->{arrangement}{use_cases} = [@{$use_cases}[grep {!($_ & 1)} 0..$#$use_cases]];
    $use_cases = {@$use_cases};
  }

  ref $use_cases eq 'HASH'
    || throw Exception => 'wrong use cases specification: hash or array should be used';

  while (my ($name, $val) = each %$use_cases){
    $self->{use_cases}{$name} = $self->m_use_case($name, $val);
  }
}

# on result:
#   for each $opt, specified in restrictions:
#   $self->{restrictions}{$opt} = [@options_conflicting_with_opt];
# throws: Exceptions::Exception
sub m_restrictions
{
  my ($self, $restrs) = @_;

  ## unpack restrictions ##
  my %res;
  ref $restrs eq 'ARRAY'
    || throw Exception => 'wrong restrictions specification: array must be used';
  for (@$restrs){
    my @opts = split /\|/;
    for my $o (@opts){
      exists $self->{options}{$o}
        || throw Exception => "unknow option '$o' is specified in restriction";
      $res{$o} ||= [];
      push $res{$o}, grep {
        my $a = $_;
        $a ne $o && !grep {$a eq $_} @{$res{$o}}
      } @opts;
    }
  }

  ## set restrictions ##
  $self->{restrictions} = \%res;
}

# on result:
#   $self->{keys}{@keys_of_option} = $option_name
#   return { keys  => [@keys_of_option],
#            type  => $type_of_the_first_key,
#            descr => $opt_value->[1],
#           (action=> $opt_value->[2] if exists),
#            arg_name => $argument_name }
# throws: Exceptions::Exception
sub m_option
{
  my ($self, $name, $opt_value) = @_;

  ## unpack $opt_value ##
  $#$opt_value < 0 && throw Exception => "wrong option '$name' specification";

  my $val = $opt_value->[0];

  ## parse the first key ##
  my $type = undef;
  my $arg_name = undef;
  if ($val =~ s/^\s*(\S+?):(\w*)(<(.+)>)?/$1/){
    $type = $2;
    $arg_name = $4 || '<arg>';
    $self->m_check_type($type);
  }

  my @keys  = split /\s+/, $val;
  $#keys < 0 && throw Exception => "no keys specified for option '$name'";

  ## save the first key for options arrangement ##
  $self->{arrangement}{first_keys}{$keys[0]} = $name;

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
    $#$opt_value > 1 ? (action => $opt_value->[2]) : (),
    arg_name => $arg_name,
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
  return if !$type;
  my $package = "CmdArgs::Types::$type";
  exists $CmdArgs::Types::{$type.'::'}
    or throw Exception => "wrong type specified '$type'. "
      ."Type '$type' should be defined by package 'CmdArgs::Types::$type'. "
	  ."See CmdArgs manual for more details.";
  eval{ $package->can('check') } || $@
    or throw Exception => "$package should have subroutine 'check'.";
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

    ## check restrictions ##
    if (exists $self->{restrictions}{$opt}){
      for (@{$self->{restrictions}{$opt}}){
        exists $self->{parsed}{options}{$_}
            && throw Exception => "option '$cur' can not be used with option "
                                 ."'$self->{parsed}{option_keys}{$_}'";
      }
    }

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
    $self->{parsed}{option_keys}{$opt} = $cur;
    # do action
    if (exists $self->{options}{$opt}{action}){
      local $_ = $param;
      &{$self->{options}{$opt}{action}}($param);
    }
    $args->[0] = '-'.$args->[0] if $add_sub;

    $opt eq 'HELP'    && throw CmdArgsInfo => $self->m_help_message;
    $opt eq 'VERSION' && throw CmdArgsInfo => $self->m_version_message;

    return ['opt', $opt, $cur]; #< $cur here needed only for nicer error message.
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
        my $present = !m_is_p_empty($iter->[1]) && m_value_p($iter->[1]) eq $cur;
        if (!$cur->[2] || eval{$self->m_check_arg($atom->[1], $cur->[2])}){
          push @ret, [$cur->[4] ? $seq : m_get_next_p($seq), m_p_add($iter->[1], $cur)];
        }
        elsif($cur->[2] && $@){
          # m_check_arg failed
          push @{$self->{parse}{failed_arg_checks}}, $@;
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
        my $present = !m_is_p_empty($iter->[1]) && m_value_p($iter->[1]) eq $cur;
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

  ## init all arrays arguments ##
  my $uc = $self->{use_cases}{$self->{parsed}{use_case}};
  for (my $s = $uc->{sequence}; !m_is_p_empty($s); m_move_next_p($s)){
    my $cur = m_value_p($s);
    $self->{parsed}{args}{$cur->[1]} = [] if $cur->[0] eq 'arg' && $cur->[4];
  }

  ## set arguments values ##
  for (my $p = $iter->[1]; !m_is_p_empty($p); m_move_next_p($p)){
    my $cur = m_value_p($p);
    $cur->[0] eq 'arg' || throw InternalError => "wrong type '$cur->[0]' of arguments sequence";
    if ($cur->[4]){
    # array #
      unshift @{$self->{parsed}{args}{$cur->[1]}}, pop @args;
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
__END__

=head1 METHODS

=over

=item declare($version, section => value, ...)

throws: string

$version is a string, for example, '1.0.1'.

B<SECTIONS:>

=over

=item options

  options => { opt_name => ['opt_declaration', 'option help message', \&action], ...}
  opt_name - is the user-defined name of the option.
  opt_declaration:
    'key' - switch option (no arguments) 'key'.
    'key key_2 key_3' - the same. 'key', 'key_2', 'key_3' are synonims.
    'key:' - option with an argument of any type.
    'key:<ARG_NAME>' - the same, but use ARG_NAME for argument name in help message.
    'key:type' - option with an argument of 'type' type.
    'key:type key_2 key_3' - the same. 'key', 'key_2', 'key_3' are synonims.
    'key:type<ARG_NAME> key_2 key_3' - the same, but use ARG_NAME for argument name
                                       in help message.
  &action - an action-subroutine.

Action-subroutine will be executed on each occurance of the option.
Being within action-subroutine you can use given option's argument by accessing
$_[0] or $_ variables. Their values are identical.

Options '--help' and '--version' are automatically generated.

You can hide an option from the help message,
by specifying explicit C<undef> value for its description, e.g.:

  options => { hiden_opt => ['--hiden', undef], ... },

=item groups

Named groups of options.

  groups => { group_name => [qw(opt_1 opt_2 ...], ... }

If I<groups> section is missed, by default there is I<OPTIONS> group contained all options.

=item use_cases

It declares use cases, that is alternate sequences of options and arguments.

  use_cases => { use_case_name => ['atoms_list', 'use case help message'], ... }

where:

  'atoms_list' = list of space separated atoms.
  'atom' = group_name | opt_name | arg_name
  group_name - means that at this place an options from specified group can appear.
  opt_name - option 'opt_name' must be placed here.
  arg_name - an argument named 'arg_name'.
  arg_name: - an argument with value of any type.
  arg_name:type - an argument with value of the specified type
  arg_name... - array of arguments. One or more arguments are permitted.
  arg_name...? - array of arguments. Zero or more arguments are permitted.
  arg_name? - optional argument

To preserve use-cases order you should use [] instead of {}:

  use_cases => [ use_case_name => [ ... ], ... ],

If I<use_cases> section is missed, by default there is I<main> use case declared as C<['OPTIONS args...', '']>.

=item restrictions

  restrictions => ['opt_1|opt_2|opt_3', ...]

That is, opt_1, opt_2 and opt_3 can not appear simultaneously.

=back

=item parse($string)

throws: Exceptions::List

Parse $string or @ARGV array if $string is not specified.

=item arg($name)

Get argument with name '$name'.
If argument is specified as 'name...' returns a reference to the array.

=item opt($name)

Get value of the '$name' option.

=item is_opt($name)

Check whether the '$name' option is appeared.

=item args

Returns a hash contained all parsed arguments.

=item opts

Return a hash contained all parsed options.

=item use_case

Return name of parsed use case.

=back

=head1 TYPES

To declare a new type, a corresponding package should be defined.
To define 'MyType' there should be package named 'CmdArgs::Types::MyType',
that contains subroutine 'check'.
Subroutine 'check' must validate argument by returning positive boolean value.
For example:

  {
    package CmdArgs::Types::MyTypeName;
    sub check
    {
      my ($class, $arg) = @_;
      -f $arg or die "'$arg' is not a file\n"
    }
  }

=head1 AUTHOR

  Alexander Smirnov <zoocide@gmail.com>

=cut

