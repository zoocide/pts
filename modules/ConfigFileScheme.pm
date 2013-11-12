package ConfigFileScheme;
use strict;
use Exceptions;

=head1 SYNOPSIS

  my $scheme = ConfigFileScheme->new(
    strict     => 1,                      ##< prevent undeclared variables

    multiline  => {'group' => [@vars],},  ##< specify multi-line variables
    join_lines => {'group' => [@vars],},  ##< specify joined multi-line variables
    required   => {'group' => [@vars],},  ##< specify required variables
    #^^^ for these keys use 1 to specify all variables
    #    {'group' => [@vars]}   -- points to @vars from 'group'
    #    {'group' => 1}         -- points to all variables in 'group'
    #    1                      -- points to all variables

    struct     => {'group' => [@vars],},  ##< specify config_file structure
  );

  my $bool = $scheme->is_multiline ('group', 'var');
  my $bool = $scheme->is_join_lines('group', 'var');
  my $bool = $scheme->is_valid     ('group', 'var');
  try{
    $scheme->check_required({'group' => [@vars],...});
  }
  catch{
    ...
  } 'Exceptions::List';

=head1 DESCRIPTION

  Config file structure:
  -------------------------------
  |
  |# comment is the line starting from '#'
  |    # another comment
  |# Variables before any group declaration are placed in '' group (general group).
  |var_from_general_group = value
  |[group_1]
  |var_form_gorup_1 = value
  |multiline_variable = elem1 elem2
  |   elem3 elem4
  | # comment
  | elem5 #this_is_not
  |[group_2]
  |var_from_group_2 = value

=cut

# throws: string, Exceptions::Exception
sub new
{
  my $class = shift;
  my %decl = @_;
  my $self = bless {}, $class;

  ## check 'strict' parameter ##
  $self->{strict} = exists $decl{strict} ? $decl{strict} : 0;
  ref $self->{strict} && throw Exception => 'ConfigFileScheme: wrong value for \'strict\' parameter';
  delete $decl{strict} if exists $decl{strict};

  $self->m_parse_decl_section('struct'    , \%decl);
  $self->m_parse_decl_section('required'  , \%decl);
  $self->m_parse_decl_section('multiline' , \%decl);
  $self->m_parse_decl_section('join_lines', \%decl);
  keys %decl && throw Exception => 'ConfigFileScheme: unknown parameters ['.(join ', ', keys %decl).']';
  $self->m_prepare_scheme;
  $self
}

sub is_multiline
{
  my $r = $_[0]{multiline};
  $r && (!ref $r
    || exists $r->{$_[1]} && $r->{$_[1]} && (!ref $r->{$_[1]}
      || grep $_[2] eq $_, @{$r->{$_[1]}}
    )
  )
}

sub is_join_lines
{
  my $r = $_[0]{join_lines};
  $r && (!ref $r
    || exists $r->{$_[1]} && $r->{$_[1]} && (!ref $r->{$_[1]}
      || grep $_[2] eq $_, @{$r->{$_[1]}}
    )
  )
}

sub is_valid
{
  return 1 if !$_[0]{strict};
  my $r = $_[0]{struct};
  $r && (!ref $r
    || exists $r->{$_[1]} && $r->{$_[1]} && (!ref $r->{$_[1]}
      || grep $_[2] eq $_, @{$r->{$_[1]}}
    )
  )
}

# throws: 'Exceptions::List'
sub check_required
{
  my ($self, $conf) = @_;
  my @errors;

  ## check required ##
  if ($self->{required}){
    while (my ($gr, $vars) = each %{$self->{required}}){
      for (keys %$vars){
        push @errors, Exceptions::Exception->new("${gr}::$_ is not specified") if !exists $conf->{$gr}{$_};
      }
    }
  }

  @errors && throw List => @errors;
}

# throws: Exceptions::Exception
sub m_parse_decl_section
{
  my ($self, $name, $decl) = @_;
  if (exists $decl->{$name}){
    ## check hash ##
    (!ref $decl->{$name} || ref $decl->{$name} eq 'HASH')
      or throw Exception => "wrong ConfigFileScheme declaration for section '$name'";
    if (ref $decl->{$name}){
      for(keys %{$decl->{$name}}){
        (!ref $decl->{$name}{$_} || ref $decl->{$name}{$_} eq 'ARRAY')
           or throw Exception => "wrong ConfigFileScheme declaration for section '$name'";
      }
    }

    ## set declaration section ##
    $self->{$name} = $decl->{$name};
    delete $decl->{$name};
  }
  else{
    $self->{$name} = 0;
  }
}

# throws: Exceptions::List
sub m_prepare_scheme
{
  my ($self) = shift;
  my @errors;

  ## process 'required' section ##
  if (my $req = $self->{required}){
    my $s = $self->{struct};
    if (!ref $req){
      $self->{required} = {};
      while (my ($gr, $vars) = each %{$self->{struct}}){
        $self->{required}{$gr} = {map +($_, 1), @$vars} if ref $vars;
      }
    }
    else{
      ## check 'required' is contained in 'struct' ##
      push @errors, m_struct_contains($s, $req, 'required');

      ## convert 'required' ##
      $self->{required} = {};
      for my $gr (keys %$req){
        if (ref $req->{$gr}){
          $self->{required}{$gr} = {map +($_, 1), @{$req->{$gr}}};
        }
        elsif ($req->{$gr} && ref $s->{$gr}){
          $self->{required}{$gr} = {map +($_, 1), @{$s->{$gr}}};
        }
      }
    }
  }

  throw List => @errors if @errors;
}

# throws: -
sub m_struct_contains
{
  my ($struct, $h, $name) = @_;
  return if !ref $struct || !ref $h;
  my @errors;

  my @grs = grep exists $struct->{$_}, keys %$h;
  if (@grs != keys %$h){
    push @errors, Exceptions::Exception->new("ConfigFileScheme: $name: struct not contains group".$_)
      for grep !exists $struct->{$_}, keys %$h;
  }

  for my $gr (@grs){
    next if !ref $struct->{$gr} || !ref $h->{$gr};
    push @errors, Exceptions::Exception->new("ConfigFileScheme: $name: struct not contains variable $gr::$_")
      for grep {my $k = $_; !grep $k eq $_, @{$struct->{$gr}}} @{$h->{$gr}};
  }

  @errors
}

1;

