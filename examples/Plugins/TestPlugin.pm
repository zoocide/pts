package Plugins::TestPlugin;
use base qw(Plugins::Base);
use Exceptions;

=head1 DESCRIPTION

Test plugin.

=cut

sub process
{
  my ($class, $task) = @_;
  print "task '", $task->name, "' processing...\n";
  if ($task->has_var('', 'content')){
    print "task says: '", $task->get_var('', 'content'), "'\n";
  }
  else{
    throw Exception => "task has nothing to say";
  }
  try {
    $task->reload_config(multiline => {'' => [qw(content)]});
    if ($task->has_var('', 'content')){
      print "content = "
        , join(', ', map "'$_'", $task->get_arr('','content'))
        , "\n";
    }
  };
  1
}

1;

