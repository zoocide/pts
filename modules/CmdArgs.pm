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
  my @iters = map { [$_, [@{$self->{use_cases}{$_}{sequence}}]] } keys %{$self->{use_cases}};
  while (@args && @iters){
    my $atom = $self->m_get_atom(\@args);
    @iters = grep { $self->m_fwd_iter($atom, $_->[1]) } @iters;
    @iters || die "wrong arguments";
  }
  use Data::Dumper;
  print Dumper(\@iters);
  @iters = grep { $self->m_fwd_iter(['end'], $_->[1]) } @iters;
  $#iters < 0 && die "wrong arguments";
  $#iters > 0 && die "internal error: more then one use cases are suitable\n";
  $self->m_set_arg_names($iters[0][0]);
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
  !$type || "CmdArgs::Types::$type"->check($arg) || die "wrong argument $arg\n";
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
    (ref $cur && grep {$atom->[1] eq $_} @{$self->{groups}{$cur->[0]}}) || return 0;
  }
  elsif ($atom->[0] eq 'arg'){
  # argument #
    shift @$iter while @$iter && ref $iter->[0];
    @$iter || return 0;
    my $cur = $iter->[0];

    $cur =~ /^(.+?):(.*?)(\+?)(\??)$/ || die "internal error (can`t parse '$cur')";
    my ($name, $type, $rep, $opt) = ($1, $2, $3, $4);
    $self->m_check_arg($atom->[1], $type);
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

__END__
# usage:
#
# use CmdArgs;
# $CmdArgs::usage_msg = "arguments...\n"; # print "usage: script.pl $usage_msg"
# $CmdArgs::help_msg = "script.pl is used for...\n";
# $CmdArgs::version_msg = "version = 0.0.1\n";
#
# my $args = CmdArgs->new();
# my @tail_args;
# $args->getopts('abcdef:g', 'arg_1', 'arg_2', ..., \@tail_args);
# $args->require('a|bcd', 'arg_1:test_name', 'arg_2:a_type', 'e|g', ...);
#
# if   ($args->{a}){...}
# elsif($args->{b}){...}
# print $args->{arg_1};

use Carp;
use Getopt::Std qw();

our $usage_msg   = "change \$CmdArgs::usage_msg to show your usage message\n";
our $help_msg    = "change \$CmdArgs::help_msg to show tour help message\n";
our $version_msg = "change \$CmdArgs::version_msg to show your version message\n";

# my $args = CmdArgs->new();
sub new
{
  bless {}, $_[0];
}

# return a hash ref
sub opts { my $self = shift; $self }

# getopts('azf:', 'argument_name_1', 'argument_name_2', ..., [\@args])
sub getopts
{
  my ($self, $opts_str, @arg_names) = @_;
  my $list = (@arg_names && ref $arg_names[-1] eq 'ARRAY') ? $arg_names[-1] : 0;
  $Getopt::Std::STANDARD_HELP_VERSION = 1;
  Getopt::Std::getopts($opts_str, $self) || print_usage_and_exit();
  $#ARGV < $#arg_names           && m_error('too few arguments');
  $#ARGV > $#arg_names && !$list && m_error('too many arguments');
  $list && pop @arg_names;
  $self->{$_} = shift @ARGV for @arg_names;
  $list && (@$list = @ARGV);
}

# require ('a|zf', 'argument_name:type', ...)
# type = ('test_name')
sub require
{
  my $self = shift;
  for my $restr (@_){
    $_ = $restr;
    if (/^\S+\|\S/){ # 'abc|zf|gkl'
	  my $tmpl = '|'. join '', grep {length $_ == 1} keys %$self;
	  eval "tr/$tmpl//cd, 1" or die $@; #< to interpolate variable $tmpl
	  my @groups = grep {$_} split /\|/;
	  next if $#groups <= 0;

	  my $msg = '';
	  while ($#groups > 0){
	    my $gr = shift @groups;
		my $conflict = join '', @groups;
		$msg .= "ERROR: option '$_' conflicts with '$conflict'\n" for (split //, $gr);
	  }
	  die $msg;
	}
	elsif (/^(\w+):(\w+)/){
	  exists $self->{$1} || croak "INTERNAL ERROR: wrong argument name specified in requirements";
	  my $arg = $self->{$1};
	  my $type = $2;
	  if ($type eq 'test_name'){
	    -d $arg || die "ERROR: '$arg' is not a directory\n";
	  }
	  else{
	    croak "INTERNAL ERROR: wrong type specified for argument in requirements";
	  }
	}
	else{
	  croak "INTERNAL ERROR: wrong requirement is specified";
	}
  }
}

# print_usage()
sub print_usage
{
  (my $name = $0) =~ s#.*[/\\]##;
  print "usage: $name ", $usage_msg;
}

# print_usage_and_exit()
sub print_usage_and_exit
{
  print_usage();
  exit -1;
}

# m_error('error message')
sub m_error { print "ERROR: $_[0]\n" if $_[0]; print_usage_and_exit(); }

sub main::HELP_MESSAGE
{
  my ($file) = @_;
  (my $name = $0) =~ s#.*[/\\]##;
  print $file "usage: $name ", $usage_msg, $help_msg;
}

sub main::VERSION_MESSAGE
{
  my ($file, $argstr) = @_;
  print $file $version_msg;
}

1;
