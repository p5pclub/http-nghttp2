use strict;
use warnings;
use Test::More;
use Test::LeakTrace;

use NGHTTP2::Session;

sub new_session {
    return NGHTTP2::Session->new({
        send => sub {},
        recv => sub {},
    });
}
no_leaks_ok(sub {
    my $s = new_session();
}, "normal use");

no_leaks_ok(sub {
    my $s = new_session();
    my $t = bless $s, "Evil";
}, "reblessed");

no_leaks_ok(sub {
    my $s = new_session();
    my $t = bless {}, ref $s;
}, "rogue hash");

no_leaks_ok(sub {
    my $s = new_session();
    my $t = bless \do {my $u = 0}, ref $s;
}, "rogue scalar");

no_leaks_ok(sub {
    my $s = NGHTTP2::Session->new({
        recv => sub { die "kaboom" },
    });
    $s->open_session();
    $s->recv();
}, "dying is fine");

done_testing;
