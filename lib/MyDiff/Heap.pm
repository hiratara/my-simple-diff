package MyDiff::Heap;
use strict;
use warnings;

sub new {
    my $class = shift;
    bless [] => $class;
}

sub _swap ($$) {
    my $temp = $_[0];
    $_[0] = $_[1];
    $_[1] = $temp;
    ();
}

sub push {
    my ($self, $prior, $item) = @_;
    push @$self, {prior => $prior, item => $item};

    # Ordering
    my $idx = $#$self;
    while ($idx >= 0) {
        my $parent_idx = int(($idx - 1) / 2);
        last if $self->[$idx]{prior} <= $self->[$parent_idx]{prior};
        _swap ($self->[$idx], $self->[$parent_idx]);
        $idx = $parent_idx;
    }

    ();
}

sub pop {
    my $self = shift;
    @$self or return;

    my $poped = $self->[0];

    if (my $last_item = pop @$self and @$self) {
        $self->[0] = $last_item;

        # Ordering again
        my $idx = 0;
        while ((my $child_idx = $idx * 2 + 1) < @$self) {
            # Select the bigger one
            $child_idx++
                if $child_idx + 1 < @$self &&
                   $self->[$child_idx + 1]{prior} > $self->[$child_idx]{prior};

            last if $self->[$child_idx]{prior} <= $self->[$idx]{prior};
            _swap ($self->[$child_idx], $self->[$idx]);
            $idx = $child_idx;
        }
    }

    $poped->{item};
}

1;
