package MyDiff::Heap;
use strict;
use warnings;

sub new {
    my $class = shift;
    bless [] => $class;
}

sub push {
    my ($self, $prior, $item) = @_;
    push @$self, {prior => $prior, item => $item};
    ();
}

sub pop {
    my $self = shift;
    my $item = (sort {$b->{prior} <=> $a->{prior}} @$self)[0];
    @$self = grep { $item != $_ } @$self;
    $item->{item};
}

1;
