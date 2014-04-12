use strict;
use warnings;
use Encode ();
use File::Basename qw(dirname);
use MyDiff::Diff qw(html_diff);
use Plack::App::Directory;
use Plack::Request;
use Plack::Response;
use Plack::Builder;

my $dir = dirname __FILE__;

my $app_diff = sub {
    my $req = Plack::Request->new(shift);
    my $text_from = Encode::decode 'UTF-8', ($req->param('text_from') // '');
    my $text_to   = Encode::decode 'UTF-8', ($req->param('text_to')   // '');
    my $html_body = html_diff(
        $text_from, $text_to,
        $req->param('is_word_diff')
    );

    my $res = Plack::Response->new(200);
    $res->content_type('text/html; charset=UTF-8');
    $res->body(Encode::encode 'UTF-8', $html_body);
    $res->finalize;
};

my $app_static = Plack::App::Directory->new(
    root => "$dir/static"
)->to_app;

builder {
    mount '/' => $app_static;
    mount '/ajax/diff' => $app_diff;
};
