package MyDiff::Diff;
use strict;
use warnings;
use utf8;
use List::MoreUtils qw(any);
use Algorithm::Diff qw(sdiff);
use Exporter qw(import);
our @EXPORT_OK = 'html_diff';

our $IGNORED_TERM = "\0";

sub _parse_by_regex ($$) {
    my ($text, $regex) = @_;
    my @parsed;
    while ($text =~ /($regex)/g) {
        push @parsed, $1;
    }
    return \@parsed;
}

sub _parse_words ($) { _parse_by_regex $_[0], qr/\w+|\s+|[^\w\s]+/ }
sub _parse_chars ($) { _parse_by_regex $_[0], qr/\w|\s+|[^\w\s]/ }
sub _parse_lines ($) { _parse_by_regex $_[0], qr/[^\n]*(?:\n|[^\n]$)/ }

sub _ignore_spaces ($) {
    my $ref_contents = shift;
    [map { /^\s+$/ ? $IGNORED_TERM : $_} @$ref_contents];
}

sub _recover_ignored_terms ($$$) {
    my ($original_from, $original_to, $diffs) = @_;

    my @recovered;
    my ($original_index_from, $original_index_to) = (0, 0);
    for my $diff (@$diffs) {
        push @recovered, [
            $diff->[0],
            ($diff->[1] eq $IGNORED_TERM
                ? $original_from->[$original_index_from]
                : $diff->[1]),
            ($diff->[2] eq $IGNORED_TERM
                ? $original_to->[$original_index_to]
                : $diff->[2]),
        ];

        $original_index_from++ if $diff->[0] =~ /^[uc\-]$/;
        $original_index_to++   if $diff->[0] =~ /^[uc+]$/;
    }
    \@recovered;
}

sub _normarize_diff ($) {
    my ($diffs) = @_;

    my @normarized_diff;
    my ($cur_slot, $cur_is_same);
    for my $diff (@$diffs) {
        die "You must call _recover_ignored_terms first"
                                  if any { $diff->[$_] eq $IGNORED_TERM } 1, 2;

        my $is_same = $diff->[0] eq 'u';
        if (! defined $cur_slot || $is_same xor $cur_is_same) {
            push @normarized_diff, ($cur_slot = [$diff->[0], '', '']);
            $cur_is_same = $is_same;
        }
        $cur_slot->[1] .= $diff->[1];
        $cur_slot->[2] .= $diff->[2];
    }
    \@normarized_diff;
}

sub _as_html ($) {
    my $text = shift;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/"/&quot;/g;
    $text =~ s/[ \t]/&nbsp;/g;
    $text =~ s/(\r?\n|\r)/$1<br>/g;
    $text;
}

sub _diff_to_html ($) {
    my $diffs = shift;
    my @outputs;
    for my $diff (@$diffs) {
        my $from_html = _as_html $diff->[1];
        my $to_html   = _as_html $diff->[2];
        if ($diff->[0] eq 'u') {
            push @outputs, $to_html;
        } elsif ($diff->[0] eq 'c') {
            push @outputs, "<del>$from_html</del>", "<ins>$to_html</ins>";
        } elsif ($diff->[0] eq '-') {
            push @outputs, "<del>$from_html</del>";
        } elsif ($diff->[0] eq '+') {
            push @outputs, "<ins>$to_html</ins>";
        }
    }
    join '', @outputs;
}

sub _line_diff ($$) {
    use List::Util qw(sum);
    my ($lines1, $lines2) = @_;
    my @xs = map { length $_ } @$lines1;
    my @ys = map { length $_ } @$lines2;
    my @diag;
    my $diag = sub {
        my ($x, $y) = @_;
        $x < @$lines1 && $y < @$lines2 or return; # Out of ranges

        ($diag[$y][$x] //= do {
            my $sdiff = sdiff(_ignore_spaces $lines1->[$x], _ignore_spaces $lines2->[$y]);
            $sdiff = _recover_ignored_terms($lines1->[$x], $lines2->[$y], $sdiff);
            my $cost = sum map {
                {'-' => 1, '+' => 1, 'c' => 2, 'u' => 0}->{$_->[0]}
            } @$sdiff;
            {cost => $cost, diff => $sdiff};
        })->{cost};
    };

    my $inf_left_estimate = do {
        my @memoize;
        sub ($) {
            my ($node) = @_;

            $memoize[$node->[1]][$node->[0]] //= do {
                my $left_x = @xs - $node->[0];
                my $left_y = @ys - $node->[1];

                my ($left, $diff);
                if ($left_x == $left_y) {
                    0;
                } else {
                    if ($left_x < $left_y) {
                        $left = [@ys[$node->[1] .. $#ys]];
                        $diff = $left_y - $left_x;
                    } else {
                        $left = [@xs[$node->[0] .. $#xs]];
                        $diff = $left_x - $left_y;
                    }

                    sum +(sort @$left)[0 .. ($diff - 1)];
                }
            };
        };
    };

    my @queue;
    my @status;  # $stat[$y][$x] = {from => [$x, $y], expect => $n, queued => bool};

    # CAUTION! You must prepare @status before you call this method
    my $push_node = sub ($) {
        my $node = shift;
        my $st = $status[$node->[1]][$node->[0]];
        for my $idx (0 .. $#queue) {
            my $_st = $status[$queue[$idx][1]][$queue[$idx][0]];
            if ($st->{expect} < $st->{expect}) { # sort by expect value
                splice @queue, $idx, 0, $node;
                return;
            }
        }

        push @queue, $node; # push to last
    };

    $status[0][0] = {expect => ($inf_left_estimate->([0, 0])), queued => 1};
    $push_node->([0, 0]);

    while (my $node = shift @queue) {
        my ($x, $y) = @$node;
        last if $x == @xs && $y == @ys; # GOAL!

        my $st = $status[$y][$x];
        delete $st->{queued} or next;

        my $try_node = sub {
            my ($node2, $cost) = @_;
            my ($x2, $y2) = @$node2;
            return unless $x2 <= @xs && $y2 <= @ys;

            my $expect = $st->{expect} - ($inf_left_estimate->($node))
                         + $cost + ($inf_left_estimate->($node2));
            my $st_orig = $status[$y2][$x2];
            unless (defined $st_orig and $expect >= $st_orig->{expect}) {
                $status[$y2][$x2] = {from => [$x, $y], expect => $expect, queued => 1};
                $push_node->([$x2, $y2]);
            }
        };

        $try_node->([$x + 1, $y], $xs[$x]);
        $try_node->([$x, $y + 1], $ys[$y]);
        $try_node->([$x + 1, $y + 1], $diag->($x, $y));
    }

    my @results;
    my $node = [scalar @xs, scalar @ys];
    while ($node) {
        my $st = $status[$node->[1]][$node->[0]] or die "[BUG]";
        my $next_node = $st->{from};
        unless ($next_node) {
            # starting points
            last;
        } elsif ($node->[0] == $next_node->[0]) {
            # INSERT
            unshift @results, ['+', undef, (join "", @{$lines2->[$next_node->[1]]})];
        } elsif ($node->[1] == $next_node->[1]) {
            # DELETE
            unshift @results, ['-', (join "", @{$lines1->[$next_node->[0]]}), undef];
        } else {
            # MODIFIED(diag)
            unshift @results, @{$diag[$next_node->[1]][$next_node->[0]]{diff}};
        }

        $node = $next_node;
    }
    \@results;
}

sub html_diff ($$;$) {
    my ($text1, $text2, $is_word_diff) = @_;
    my $parser = $is_word_diff ? \&_parse_words : \&_parse_chars;
    my @from = map { $parser->($_) } @{_parse_lines $text1};
    my @to   = map { $parser->($_) } @{_parse_lines $text2};
    my $sdiff = _line_diff(\@from, \@to);

    _diff_to_html(_normarize_diff($sdiff));
}

1;
__END__
