#!/usr/bin/perl -w
use strict;
use lib '../modules';
use File::HomeDir;
use File::Spec::Functions qw(catfile);
use ConfigFile;
use Exceptions;
use PtsConfig;
use CmdArgs;

my $cmd_file = 'all.commands';
my $taskset_file = 'current.set';

my $args = CmdArgs->declare(
  '0.2',
  use_cases => [
    all => ['all', 'Start testing from the beginning.'],
    continue => ['cont', 'Continue testing.'],
  ],
  options => {
    all  => ['-a --all', "Read commands from 'all.commands'."],
    cont => ['-c --continue', "Read commands from 'current.commands'."],
  }
);
$args->parse;

$cmd_file = 'current.commands' if $args->is_opt('cont');

## load global config ##
my $global_config_file = catfile(File::HomeDir->my_home, '.pts', 'test-dvm.conf');
my $global_config = ConfigFile->new(
  $global_config_file,
  required => { '' => [qw(test_suite_dir)] },
);
try {
  $global_config->load;
} catch {
  unshift @{$@}, Exceptions::Exception->new("In file '$global_config_file':");
  throw
} 'List';
## get global variables ##
my $tests_base_dir = $global_config->get_var('', 'test_suite_dir');
-d $tests_base_dir or die "'$tests_base_dir' is not a test suite directory. ",
                          "Please edit '$global_config_file'.\n";


## read command file ##
my @cmds = parse_command_file($cmd_file);

## find all tests in test_suite ##
my @tests = get_tests($tests_base_dir);
#print map $_->{src}."\n", @tests;

while (@cmds){
  my @task_names = generate_tasks('tasks', @{$cmds[0]}, @tests);
  open my $f, '>', $taskset_file or die "can not open file '$taskset_file': $!\n";
  print $f "$_\n" for @task_names;
  close $f;
  print 'number of tasks = ', scalar @task_names, "\n";
  shift @cmds;
}

# my @commands = parse_command_file('command_file');
sub parse_command_file
{
  my $file_name = shift;
  my @cmds;
  open my $f, '<', $file_name or die "can not open file '$file_name':$!\n";

  my @errors;

  for (my $l = 1; <$f>; $l++){
    next if /^\s*#/;
    chomp;
    if (/^compile\s+(\w.+?)\s*$/){
      push @cmds, [compile => $1];
    }
    elsif (/^(run(\s.*?)?)\s*$/){
      push @cmds, [run => $1];
    }
    else{
      push @errors, "$file_name: error in line $l\n";
    }
  }
  @errors && die @errors;

  close $f;
  @cmds
}

# my @tests = get_tests('test-suite/Correctness');
# test = {dir => $short_dir, out => $out_name, src => $file, land => 'f' | 'c'}
sub get_tests
{
  my ($start_dir, $short_dir) = @_;
  my $dir = $short_dir ? catfile($start_dir, $short_dir) : $start_dir;
  -d $dir || return ();
  my @ret;
  opendir my $d, $dir or return ();
  my $name;
  while ($name = readdir $d){
    next if $name =~ /^\.\.?$/;
    my $p = catfile($dir, $name);
    if (-d $p){
      push @ret, get_tests($start_dir, $short_dir ? catfile($short_dir, $name)
                                                  : $name);
    }
    elsif ($name =~ /^(.+)\.(f|c)dv$/i){
      push @ret, {dir => $short_dir, out => $1, src => $name, lang => lc $2};
    }
    else {
      #print "unrecognized filename: $p\n";
    }
  }
  closedir $d;
  @ret
}

# my $new_task_name = gen_task_name($action, $test);
sub gen_task_name
{
  my ($act, $test) = @_;
  my $d = $test->{dir};
  $d =~ tr|/\\:|--|d;
  $act.'_'.$d.'-'.$test->{out}
}

# my @task_names = generate_tasks($action, $dvm_args, @tests);
sub generate_tasks
{
  my ($tasks_dir, $act, $args, @tests) = @_;
  my @ret;

  if ($act eq 'compile'){
    ## determine language ##
    my $lang;
    if    ($args =~ /^\s*c/i){ $lang = 'c' }
    elsif ($args =~ /^\s*f/i){ $lang = 'f' }
    else { warn "Can not determine language for command: $act $args" }

    for my $t (@tests){
      next if $lang ne $t->{lang};
      my $task_name = gen_task_name($act, $t);
      my $fname = "$task_name.conf";
      my $task = ConfigFile->new(catfile($tasks_dir, $fname));
      $task->set_var(name => $task_name);
      $task->set_var(plugin => 'CompileTest');

      $task->set_var(action => $act);
      $task->set_var(dir => $t->{dir});
      $task->set_var(src => $t->{src});
      $task->set_var(out => $t->{out});
      $task->set_var(dvm_args => $args);
      $task->save;
      push @ret, $task_name;
    }
  }
  elsif ($act eq 'run'){
    for my $t (@tests){
      my $task_name = gen_task_name($act, $t);
      my $fname = "$task_name.conf";
      my $base_task_name = gen_task_name(compile => $t);
      my $task = ConfigFile->new(catfile($tasks_dir, $fname));
      $task->set_var(name => $task_name);
      $task->set_var(plugin => 'CompileTest');

      $task->set_var(action => $act);
      $task->set_var(compile_task => $base_task_name);
      $task->set_var(dvm_args => $args);
      $task->save;
      push @ret, $task_name;
    }
  }
  else {
    die "can not generate tasks for unknown action '$act'";
  }
  @ret
}
