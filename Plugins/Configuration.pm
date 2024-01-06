package Plugins::Configuration;
use Plugins::Base;
use base 'Plugins::Base';
use ConfigFile;
use File::Spec::Functions qw(catfile);

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
The '$name' task writes its argument variables into the configuration file.
Variables from the default '' group are not saved.
To see the stored variables use command `pts config:list`.
A plugin can use this task to obtain stored values this way:

  my \$conf = \$db->get_task('$name')->data;
  # now \$conf is a ConfigFile object.

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

  if ($task->get_var('', 'list', '')) {
    print_config($task);
    return;
  }
  update_config($task);
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
  ## save all arguments to the config file ##
  dbg1 and dprint("update config file '", $task->data->filename, "'");
  my %args = $task->id->args;

  # do not save the default '' group.
  delete $args{''};
  %args or return;

  my $conf = $task->data;
  while (my ($gr, $vars) = each %args) {
    while (my ($var, $val) = each %$vars) {
      $conf->set($gr, $var, @$val);
    }
  }
  dbg2 and dprint("save config file '", $conf->filename, "'");
  $conf->save;

  ## update the task object data ##
  $task->set_data($conf);
}

1
