package Plugins::SeqTest;
use v5.10;
use Plugins::Base;
use base qw(Plugins::Base);

my %h;

sub process
{
  my ($class, $task, $db) = @_;
  my $n = $task->name;
  my $last_id = $h{$n} || '';
  my $id = $h{$n} = $task->get_var('', 'id');
  print_out($task->name.": last id = $last_id, cur_id = $id\n");
  m_sleep(0.1);
  1
}

sub m_sleep
{
  select undef, undef, undef, shift;
}

1
