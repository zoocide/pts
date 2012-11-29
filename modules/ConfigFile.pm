package ConfigFile;
use strict;
use Exceptions;
use Exceptions::TextFileError;
use Exceptions::OpenFileError;
use ConfigFileScheme;

use vars qw($VERSION);
$VERSION = '0.2.0';

=head1 SYNOPSIS

  my $decl = ConfigFileScheme->new(...);
  my $cf   = ConfigFile->new($file_name, $decl);
  # or
  my $cf = ConfigFile->new($file_name);

  try{
    $cf->load;
  }
  catch{
    print map "warning: $_\n", @{$@};
  } 'Exceptions::List';

  my $gr = $cf->get_all;
  $gr->{'group'}{'var'};

  $cf->set_group('group');
  $cf->set_var('var_name', 'value');
  $cf->save;

  --------
  $cf->check_required;         ##< according to declaration
  $cf->check_required($hash);  ##< according to $hash, defining required variables
  $cf->check_required('gr' => [@vars],...); ##< hash constructor

=cut


# throws: -
sub new
{
  my $self = bless {}, shift;
  $self->init(@_);
  $self
}

sub init
{
  my $self = shift;
  my ($fname, $decl) = @_;
  $self->{fname}     = $fname;
  $self->{content}   = {};
  $self->{cur_group} = '';
  $self->{decl}      = defined $decl ? $decl : ConfigFileScheme->new;
}


## config file rules ##
# error: [complex group]
# ok   : [group]
# ok   : var_1 = a complex value
# ok   :   # comment string
# ok   : var_2 = '  a complex value  '
# error: var_3 = 'a complex value
# error: var_4 = 'a complex value' tail
# ok   : var_5 = 'a complex
# ok   :      # this is a part of the string
# ok   :
# ok   :  new lines are saved in this string
# ok   :   value'
# ok   : var_6 = head \'complex value\'
# ok   : var_7 = \\n is not a new line
# ok   : # set empty value
# ok   : var_8 =
# error:   value
# ok   : arr_1 = elm1
# ok   : arr_2 = elm1 elm2 'complex element'
# ok   : elm3
# ok   :   elm4 elm5
# ok   : arr_3 =
# ok   : elm1 elm2 elm3 elm4

# throws: Exceptions::OpenFileError, [Exceptions::TextFileError]
sub load
{
  my $self = shift;
  my $decl = $self->{decl};
  my @errors;

  open(my $f, '<', $self->{fname}) || throw OpenFileError => $self->{fname};

  my $state = 1; # 0 - read string; 1 - read scalar; 2 - read array
  my ($var, $buf, @arr, $l, $is_multiline, $is_join_lines, $str_bl);
  for($l = 1; <$f>; $l++){
    if ($state){
      if    (/^\s*(#|\r?\n?$)/){
        next;
      }
      elsif (/^\s*\[(\w+)\]\s*$/){
        $self->set_group($1);
        $state = 1;
        next;
      }
      elsif (/^\s*(\w+)\s*=\s*(.*\r?\n?)$/){
        $var = $1;
        $buf = $2;
        if (!$decl->is_valid($self->{cur_group}, $var)){
          push @errors, Exceptions::TextFileError->new($self->{fname}, $l, "invalid variable '$var'");
          $state = 1;
          next;
        }
        @arr = m_split_buf($buf);

        $str_bl = 0;
        $is_multiline  = $decl->is_multiline ($self->{cur_group}, $var);
        $is_join_lines = $decl->is_join_lines($self->{cur_group}, $var);

        if ($is_multiline){
          $state = 2;
          $self->{content}{$self->{cur_group}}{$var} = '' if $is_join_lines;
        }
        else{
          $state = 1;
          $arr[0] =~ s/\s*(\r|\n)$//g if @arr == 1;
          if (@arr > 1 && ($arr[0] || (@arr > 2 && $arr[2] !~ /^\s*$/) || @arr > 3 )){
            push @errors, Exceptions::TextFileError->new($self->{fname}, $l, 'wrong value of scalar variable');
            next;
          }
        }
      }
      elsif ($state == 2){
        @arr = m_split_buf($_);
        $buf = $_ if $is_join_lines;
      }
      else{
        push @errors, Exceptions::TextFileError->new($self->{fname}, $l, 'unrecognized line');
        next;
      }

      if (@arr % 2 == 0){
        # string not closed
        $str_bl = $l if !$str_bl;
        $state = 0;
        next;
      }
    }
    else{
    ## read string ##
      $buf .= $_ if $is_join_lines;
      my @t = m_split_buf($_);
      $arr[-1] .= shift @t;
      next if !@t;

      if (!$is_multiline && (!m_empty_end($t[0]) || @t > 1)){
        push @errors, Exceptions::TextFileError->new($self->{fname}, $l, 'wrong value of scalar variable');
        $state = 1;
        next;
      }

      push @arr, @t;
      next if (@t % 2 == 0);
      $state = $is_multiline ? 2 : 1;
    }

    ## add ##
    if    ($state == 1){
      shift @arr if @arr == 3;
      $self->set_var($var, $arr[0]);
    }
    else{
      if ($is_join_lines){
        $self->{content}{$self->{cur_group}}{$var} .= $buf;
      }
      else{
        push @{$self->{content}{$self->{cur_group}}{$var}}
             , map { $_ % 2 ? $arr[$_] : grep $_, split /\s+/, $arr[$_] } 0..$#arr;
      }
    }
  }

  if (!$state){
    push @errors, Exceptions::TextFileError->new($self->{fname}, $l-1, "unclosed string (see from line $str_bl)");
  }
  close $f;

  try{
    $self->check_required;
  }
  catch{
    push @errors, @{$@};
  } 'Exceptions::List';

  if (@errors){
    return @errors if wantarray;
    throw List => @errors;
  }
}

# throws: Exceptions::List
sub check_required
{
  my $self = shift;
  my $decl = @_ ? ConfigFileScheme->new(required => (ref $_[0] ? $_[0] : {@_}))
                : $self->{decl};
  $decl->check_required($self->{content});
}

# throws: Exceptions::OpenFileError
sub save
{
  my $self = shift;
  open(my $f, '>', $self->{fname}) || throw OpenFileError => $self->{fname};
  for my $gr_name (sort keys %{$self->{content}}){
    my $gr = $self->{content}{$gr_name};
    print $f "\n[$gr_name]\n" if $gr_name;
    for (sort keys %$gr){
      print $f "$_ = $gr->{$_}\n";
    }
  }
  close $f;
}

sub file_name { $_[0]{fname} }
sub get_all   { $_[0]{content} }
sub get_group { $_[0]{content}{$_[1]} }
sub get_var   { $_[0]{content}{$_[1]}{$_[2]} }
sub is_set    { defined $_[0]{content}{$_[1]}{$_[2]} }

sub set_group { $_[0]{cur_group} = $#_ < 1 ? '' : $_[1] }
sub set_var   { $_[0]{content}{$_[0]{cur_group}}{$_[1]} = $_[2] }
sub set_var_if_not_exists
{
  $_[0]{content}{$_[0]{cur_group}}{$_[1]} = $_[2] if !exists $_[0]{content}{$_[0]{cur_group}}{$_[1]}
}

sub m_q_ind
{
  my ($str, $i) = @_;
  $i = @_ < 2 ? index $str, '\'' : index $str, '\'',  $i;
  $i = index $str, '\'', $i+1 while $i >= 0 && (substr $str, 0, $i)=~/(^|[^\\])(\\\\)*\\$/;
  $i
}

# @strs = m_split_buf($buf); ##< split $buf in string borders
# example: "'abc' def'" => ('','abc',' def','')
sub m_split_buf
{
  my $buf = shift;
  my @ret;
  while((my $i = m_q_ind($buf)) >= 0){
    push @ret, m_normalize_str(substr($buf, 0, $i));
    $buf = substr $buf, $i + 1;
  }
  push @ret, m_normalize_str($buf);
  @ret
}

sub m_empty_end { !$_[0] || $_[0] =~ /^\s*\r?\n?$/ }

# convert '\'' to ''' and '\\' to '\'
sub m_normalize_str
{
  my $ret = shift;
  $ret =~ s/\\(\\|\')/$1/g;
  $ret
}

1;

