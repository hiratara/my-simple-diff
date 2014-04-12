package MyDiff::Diff;
use strict;
use warnings;
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

sub _diff_to_html ($$) {
    my ($original, $diffs) = @_;
    my @outputs;
    my $original_index = 0;
    for my $diff (@$diffs) {
        my $original_term = $original->[$original_index];
        my $diff_from = $diff->[1] eq $IGNORED_TERM
                            ? $original_term : $diff->[1];
        my $diff_to   = $diff->[2] eq $IGNORED_TERM ? ' ' : $diff->[2];
        if ($diff->[0] eq 'u') {
            $original_index++;
            push @outputs, $diff_from;
        } elsif ($diff->[0] eq 'c') {
            $original_index++;
            push @outputs, "<del>$diff_from</del>", "<ins>$diff_to</ins>";
        } elsif ($diff->[0] eq '-') {
            push @outputs, "<del>$diff_from</del>";
            $original_index++;
        } elsif ($diff->[0] eq '+') {
            push @outputs, "<ins>$diff_to</ins>";
        }
    }
    my $html = join '', @outputs;
    $html =~ s/(\r?\n|\r)/$1<br>/g;
    $html;
}

sub html_diff ($$;$) {
    my ($text1, $text2, $is_word_diff) = @_;
    my $parser = $is_word_diff ? \&_parse_words : \&_parse_chars;
    my $from = $parser->($text1);
    my $to   = $parser->($text2);
    my $sdiff = sdiff(_ignore_spaces $from, _ignore_spaces $to);

     _diff_to_html($from, $sdiff);
}

1;
__END__
