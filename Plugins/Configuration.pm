package Plugins::Configuration;
use Plugins::Base;
use base 'Plugins::Base';
use ConfigFile;
use File::Spec::Functions qw(catfile);
use PtsColorScheme;

my ($ci, $cc, $ccom, $ce) = (clr_italic, clr_code, clr_comment, clr_end);

sub on_task_create
{
  my ($class, $task, $db) = @_;
  my $conf = load_config($task);
  $task->set_data($conf);
}

sub help_message
{
  my $class = shift;
  my $task = shift;

  my $name = $task->id->short_id;
  return <<EOT;
The ${ci}$name$ce task writes its argument variables into the configuration file.
Variables from the default ${ci}''$ce group are not saved.
To save a variable use command ${cc}pts config:group::var=value$ce.
To see the stored variables use command ${cc}pts config:list$ce.
To remove a variable from the file use command ${cc}pts config:unset=group::var$ce.
A plugin can use this task to obtain stored values this way:

  ${cc}my \$conf = \$db->get_task('$name')->data;$ce
  ${ccom}# now \$conf is a ConfigFile object.$ce

EOT
}

sub on_prepare
{
  my $class = shift;
  my $task = shift;
  my $pind = \shift;
  my $all_tasks = shift;
  my $prepared_tasks = shift;
  my $db = shift;

  my $name = $task->id->short_id;

  if ($task->get_var('', 'list', '')) {
    print_config($task);
    return;
  }

  my $force_update;
  if (my @vars = $task->get_arr('', 'unset', [])) {
    my $conf = $task->data;
    $force_update = 1;
    for (@vars) {
      /^(\w+)::(\w+)$/ or die "wrong value specified: $name:unset='$_'\n";
      $conf->unset($1, $2);
    }
  }
  update_config($task, $force_update);
}

sub load_config
{
  my $task = shift;

  $task->make_data_dir;

  my $ddir = $task->data_dir;
  my $fname = catfile($ddir, 'config');
  dbg2 and dprint("load config file '$fname'");
  my $conf = ConfigFile->new($fname);
  -f $fname and $conf->load;
  $conf
}

sub print_config
{
  my $task = shift;
  my $conf = $task->data;
  dbg1 and dprint("print config file '", $conf->filename, "'");
  for my $gr (sort $conf->group_names) {
    for my $var (sort $conf->var_names($gr)) {
      print_out("${gr}::$var = ", $conf->get_var($gr, $var), "\n");
    }
  }
}

sub update_config
{
  my $task = shift;
  my $force = shift;
  ## save all arguments to the config file ##
  dbg1 and dprint("update config file '", $task->data->filename, "'");
  my %args = $task->id->args;

  # do not save the default '' group.
  delete $args{''};
  %args || $force or return;

  my $conf = $task->data;
  while (my ($gr, $vars) = each %args) {
    while (my ($var, $val) = each %$vars) {
      $conf->set($gr, $var, @$val);
    }
  }
  dbg2 and dprint("save config file '", $conf->filename, "'");
  $conf->save;
}

1
