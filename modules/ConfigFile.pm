package ConfigFile;
use strict;
use Exceptions;

=head1 SYNOPSIS

  my $cf = ConfigFile->new($file_name);

  try{
    $cf->load;
  };
  catch{
    print
  } 'ConfigFileException';


=cut

#my $cf = ConfigFile->new($file_name);
#
#$cf->load;
#
#my $gr = $cf->get_all;
#$gr->{'group'}{'var'};
#
#$cf->set_group('group');
#$cf->set_var('var_name', 'value');
#$cf->save;


sub new
{
  my $class = shift;
  my ($fname) = @_;
  my $self = bless {
    fname     => $fname,
    content   => {},
    cur_group => '',
  }, $class;
  $self
}

sub load
{
  my $self = shift;
  open(my $f, '<', $self->{fname}) || die "can`t open file '$self->{fname}': $!\n";
  my $l = 0;
  my @lines = map {s/^\s+|^#.*|\s+$//g; $l++; $_ ? ($l, $_) : () } <$f>;
  close $f;
  for (my $i = 0; $i < @lines; $i += 2 ){
    ($l, $_) = @lines[$i, $i+1];
    if    (/^\[(\w+)\]$/){
      $self->set_group($1);
    }
    elsif (/^(\w+)\s*=\s*(.+)/){
      my ($var, $val) = ($1, $2);
      $val =~ s/^'(.*?)'$/$1/;
      $self->set_var($var, $val);
    }
    else{
      print "error: unrecognized line $l in config file '$self->{fname}'\n";
    }
  }
}

sub save
{
  my $self = shift;
  open(my $f, '>', $self->{fname}) || die "can`t open file '$self->{fname}': $!\n";
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
sub set_var_if_not_exists { $_[0]{content}{$_[0]{cur_group}}{$_[1]} = $_[2] if !exists $_[0]{content}{$_[0]{cur_group}}{$_[1]} }

1;

