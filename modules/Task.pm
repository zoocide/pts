package Task;
use strict;
use Carp qw(croak);
use ConfigFile;
use ConfigFileScheme;
use Exceptions;
use File::Path qw(make_path remove_tree);
use File::Spec::Functions qw(splitdir catdir);
use Scalar::Util qw(blessed);
use Plugins::Base qw(print_out);
BEGIN{
  eval {
    require 'Time/HiRes.pm';
    Time::HiRes->import('time');
  };
}

=head1 SYNOPSIS

  my $task = Task->new($Task_ID_obj, 'task.conf', 'task/data/dir');

  # reload config file of the task using your scheme.
  $task->reload_config(multiline => 1, ...);

  $task->make_data_dir;
  # or
  $task->make_data_dir($new_task_dir);

  chdir $task->data_dir;

  my $var = 'default_value';
  $var = $task->get_var('', 'var') if $task->has_var('', 'var');

  $var = $task->get_var('', 'var', 'default_value');
  @arr = $task->get_arr('', 'var', @default_value);

  ======== DEBUG ========
  $task->DEBUG(@messages_to_print);      ##< print debug messages
  $task->DEBUG_RESET(1, 2, 3);           ##< reset timers 1, 2, 3
  $task->DEBUG_T(2, @messages);          ##< print messages and time of timer 2
  $task->DEBUG_TR(2, @messages);         ##< print messages and time of timer 2; reset timer 2
=cut

sub new
{
  my $self = bless {}, shift;
  $self->init(@_);
  $self
}

sub id     { $_[0]{id} }
sub name   { $_[0]{name} }
sub index  { $_[0]{index} }
sub plugin { $_[0]{plugin} }
sub data_dir { $_[0]{data_dir} }
sub task_dir { $_[0]{task_dir} }
sub set_name { $_[0]{name} = $_[1] }
sub set_debug { $_[0]{debug} = $_[1] }
sub set_index { $_[0]{index} = $_[1] }

# $task->make_data_dir;
# # or #
# $task->make_data_dir('new/data/dir');
sub make_data_dir
{
  $_[0]{data_dir} = $_[1] if defined $_[1];
  make_path($_[0]{data_dir})
}
sub clear_data_dir
{
  remove_tree( $_[0]{data_dir}, {keep_root => 1} );
}

sub DEBUG   { $_[0]->{debug} && print_out 'DEBUG: ', @_[1..$#_], "\n" }
sub DEBUG_T
{
  return if !$_[0]->{debug};
  my $t = sprintf '%.6f', time - $_[0]->{debug_time}{$_[1]};
  print_out "DEBUG [${t}s]: ", @_[2..$#_], "\n";
}
sub DEBUG_RESET{ my $t = time; $_[0]->{debug_time}{$_} = $t for @_[1..$#_] }
sub DEBUG_TR{ $_[0]->DEBUG_T(@_[1..$#_]); $_[0]->DEBUG_RESET($_[1]) }

# my $bool = $task->has_var('group_name', 'var_name');
sub has_var
{
  $_[0]{conf}->is_set($_[1], $_[2])
}

# my $var = $task->get_var('group_name', 'var_name', 'default_value');
# throws: Exceptions::Exception
sub get_var
{
  my $c = $_[0]{conf};
  if (!$c->is_set($_[1], $_[2])){
    if ($#_ < 3) {
      my $fname = $_[0]->{filename};
      throw Exception => "$fname: variable '".($_[1] ? "$_[1]::" : '')."$_[2]' is not set";
    }
    return $_[3];
  }
  $c->get_var(@_[1,2])
}

# my @arr = $task->get_arr('group_name', 'var_name', @default_value);
# throws: Exceptions::Exception
sub get_arr
{
  my $c = $_[0]{conf};
  if (!$c->is_set($_[1], $_[2])){
    if ($#_ < 3) {
      my $fname = $_[0]->{filename};
      throw Exception => "$fname: variable '".($_[1] ? "$_[1]::" : '')."$_[2]' is not set";
    }
    return $#_ == 3 && ref $_[3] eq 'ARRAY' ? @{$_[3]} : @_[3..$#_];
  }
  $c->get_arr(@_[1,2])
}

# my @vars = $task->get_vars('group_name', @var_names);
# throws: Exceptions::List
sub get_vars
{
  my $self = shift;
  my $gr   = shift;
  my $c = $_[0]{conf};
  my @missed = grep !$c->is_set($gr, $_), @_;
  if (@missed){
    $gr .= '::' if $gr;
    my $fname = $self->{filename};
    throw List => map Exceptions::Exception->new("$fname: variable '$gr$_' is not set"), @missed;
  }
  map $c->get_vars($gr, $_), @_;
}

# throws: Exceptions::List
sub init
{
  my ($self, $id, $filename, $data_dir) = @_;
  croak "$id is not a Task::ID object" if !blessed($id) || !$id->isa('Task::ID');
  $self->{id} = $id;
  $self->{index} = -1;
  $self->{debug} = 0;
  $self->{filename} = $filename;
  $self->{data_dir} = $data_dir;
  my @task_path = splitdir($filename);
  $self->{task_dir} = catdir(@task_path[0..$#task_path-1]);
  my $conf;
  try{
    $conf = ConfigFile->new($filename, required => {'' => ['plugin']});
    ## set name ##
    $conf->set_group('');
    $conf->set_var('name', $id->short_id);
    ## set task arguments ##
    for (my ($gr, $vars) = $id->args) {
      $conf->set_group($gr);
      $conf->set_var($_, @{$vars->{$_}}) for keys %$vars;
    }
    ## load task ##
    $conf->skip_unrecognized_lines(1);
    $conf->load;

    $self->{ conf } = $conf;
    $self->{plugin} = $conf->get_var('', 'plugin');
    $self->{ name } = $conf->get_var('', 'name');
  }
  make_exlist
  catch{
    push @{$@}, Exceptions::Exception->new("Can not create task '$id'");
    throw;
  };
}

# $task->reload_config(ConfigFileScheme_obj);
# or
# $task->reload_config(multiline => 1, ...);
sub reload_config
{
  my $self = shift;
  my $scheme = (blessed($_[0]) && $_[0]->isa('ConfigFileScheme'))
             ? shift
             : ConfigFileScheme->new(@_);
  my $conf = ConfigFile->new($self->{filename}, $scheme);
  ## set name ##
  $conf->set_group('');
  $conf->set_var('name', $self->{id}->short_id);
  ## set task arguments ##
  for (my ($gr, $vars) = $self->{id}->args) {
    $conf->set_group($gr);
    $conf->set_var($_, @{$vars->{$_}}) for keys %$vars;
  }
  ## load task ##
  $conf->load;
  $self->{ conf } = $conf;
}


package Task::ID;
use Exceptions;
use overload '""' => sub { $_[0]->id };

sub new
{
  my $class = shift;

  my $self = bless {
    # example:
    # short_id => 'short_id', #corresponding file short_id.conf
    # id => 'short_id:arg1=value1,arg2=e1 e2',
    # args => {'' => {arg1 => ['value1'], arg2=['e1', 'e2']}},
    # args_str => 'arg1=value1,arg2=e1 e2',
  }, $class;
  $self->reset(@_);
  $self
}

sub short_id { $_[0]{short_id} }
sub id { $_[0]{id} }
# my %args = $tid->args; #< ('gr_1' => {arg1 => ['elm 1',...],...},...)
sub args { %{$_[0]{args}} }
sub args_str { $_[0]{args_str} }

sub reset
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
        '(?:[^\\']++|\\.)++' |
        "(?:[^\\"]++|\\.)++"
      )*+
    )
    (?{
      $args{$vg}{$vn} = [$^N];
    })
  >x;
  if (!($s =~ /^\s*([^:]+?) \s* (?: :(?:$arg(?:,$arg)*+)? )?$/x)) {
    throw Exception => "wrong task specification '$s'";
  }
  while (my ($g, $cnt) = each %args) {
    while (my ($v, $val) = each %$cnt) {
      $args{$g}{$v} = [m_parse_value($val->[0])];
    }
  }
  $self->{short_id} = $1;
  $self->{id} = $1;
  my $args_str = join ',', map {
    my $gr = $_;
    join ',', map {
      my $val = $args{$gr}{$_};
      "${gr}::$_=".join ' ', map {s/([\\ \$'",])/\\$1/gr =~ s/\n/\\n/gr =~ s/\t/\\t/gr} @$val
    } sort keys %{$args{$gr}}
  } sort keys %args;
  $self->{id} .= ':'.$args_str if $args_str;
  $self->{args} = \%args;
  $self->{args_str} = $args_str;
}

sub m_parse_value
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

1;

__END__

=head1 METHODS

=over

=item id()

Method returns object Task::ID for this task.

=item name()

Method returns display name of the task.
It is constructed while task creation, based on I<name> variable from configuration file
and can be changed by I<set_name> method.

=item index()

Method returns index of the task.

=item plugin()

Method returns plugin name.

=item data_dir()

Method returns path to the task data directory.

=item task_dir()

Method returns path to the directory containing task configuration file.

=item set_name($name)

Set task display name.
It does not affect variable I<name>.

=item set_index($ind)

Set task index.

=item make_data_dir($dir)

Creates task data directory.
If C<$dir> is specified, method changes task data directory to that value.

=item clear_data_dir()

Delete all content of the task data directory.

=item has_var($group_name, $var_name)

Return true if configuration file contains specified variable.

=item get_var($group_name, $var_name, $default_value)

Return string value of the specified variable.
Method returns $defualt_value if the variable is not set.
It raises exception when variable is not set and $default_value is not specified.

=item get_arr($group_name, $var_name, @default_value)

Return list value of the specified variable.
Method returns @defualt_value if the variable is not set.
Also, default value can be specified as a list reference, e.g
C<$task->get_arr('', 'var', [])>.
It is useful to specify empty list as default value.
Method raises exception when variable is not set and $default_value is not specified.

=item reload_config(SCHEME)

Reload config file with the specified SCHEME.
SCHEME could be a ConfigFileScheme object or scheme specification, e.g.:

C<< $task->reload_config(multiline => 1, ...); >>

Task name, plugin will not change even if the corresponding variables change.

Before configuration file read, the following actions will be performed.
1 - variable I<name> will be set to task short_id.
2 - variables from task arguments will be set.

=back

=head2 DEPRECATED METHODS

=over

=item set_debug($bool)

Method turns on and off debug messages.
Affected methods are: C<DEBUG>, C<DEBUG_T>, C<DEBUG_TR>.

=item DEBUG(@list)

When debug mode is on, print debug message.

=item DEBUG_T($timer_name, @list)

Print debug message and elapsed time from last $timer_name reset.

=item DEBUG_RESET(@timer_names)

Reset specified timers.

=item DEBUG_TR($timer_name, @list)

Same as

  $task->DEBUG_T($timer_name, @list);
  $task->DEBUG_RESET($timer_name);

=item get_vars($group_name, @var_names)

Return string values of the specified variables.
It raises exception when any variable is not set.

=back

=cut
