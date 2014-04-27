use strict;
use warnings;
use MyDiff::Heap;
use Test::More;

my $queue = MyDiff::Heap->new;
is $queue->pop, undef, "Empty";

$queue->push(3 => 'C');
$queue->push(9 => 'I');
$queue->push(1 => 'A');
$queue->push(4 => 'D');
$queue->push(7 => 'G');
is $queue->pop, 'I';
is $queue->pop, 'G';
is $queue->pop, 'D';

$queue->push(6 => 'F');
$queue->push(8 => 'H');
$queue->push(2 => 'B');
$queue->push(5 => 'E');
is $queue->pop, 'H';
is $queue->pop, 'F';
is $queue->pop, 'E';
is $queue->pop, 'C';
is $queue->pop, 'B';
is $queue->pop, 'A';
is $queue->pop, undef, "Empty";

done_testing;
