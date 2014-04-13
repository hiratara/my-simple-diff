package MyDiff::Diff;
use strict;
use warnings;
use utf8;
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
    my ($cur_stat, $cur_slot);
    for my $diff (@$diffs) {
        if (! defined $cur_stat || $diff->[0] ne $cur_stat) {
            push @normarized_diff, ($cur_slot = [$diff->[0], '', '']);
            $cur_stat = $diff->[0];
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
            push @outputs, $from_html;
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

sub html_diff ($$;$) {
    my ($text1, $text2, $is_word_diff) = @_;
    my $parser = $is_word_diff ? \&_parse_words : \&_parse_chars;
    my $from = $parser->($text1);
    my $to   = $parser->($text2);
    my $sdiff = sdiff(_ignore_spaces $from, _ignore_spaces $to);

    _diff_to_html(_normarize_diff(_recover_ignored_terms($from, $to, $sdiff)));
}

1;
__END__
