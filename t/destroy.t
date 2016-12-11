use strict;
use warnings;
use Test::More;
use NGHTTP2::Session;

sub new_session {
    return NGHTTP2::Session->new(
        {
            send => sub { },
            recv => sub { },
        }
    );
}

SKIP: {
    eval { require Test::LeakTrace; 1; }
        or skip 'You need Test::LeakTrace for this', 6;

    Test::LeakTrace->import();

    no_leaks_ok(
        sub {
            my $s = new_session();
        },
        "normal use"
    );

    no_leaks_ok(
        sub {
            my $s = new_session();
            my $t = bless $s, "Evil";
        },
        "reblessed"
    );

    no_leaks_ok(
        sub {
            my $s = new_session();
            my $t = bless {}, ref $s;
        },
        "rogue hash"
    );

    no_leaks_ok(
        sub {
            my $s = new_session();
            my $t = bless \do { my $u = 0 }, ref $s;
        },
        "rogue scalar"
    );

    no_leaks_ok(
        sub {
            my $s = NGHTTP2::Session->new(
                {
                    recv => sub { die "kaboom" },
                }
            );
            $s->open_session();
            $s->recv();
        },
        "dying is fine"
    );

}

SKIP: {
    eval { require Test::MemoryGrowth; 1; }
        or skip 'You need Test::MemoryGrowth for this', 1;

    Test::MemoryGrowth->import();

    no_growth(
        sub {
            my $s = new_session();
            my $t = bless \do { my $u = 0 }, ref $s;
        },
        'No memory growth via Test::MemoryGrowth'
    );

}

done_testing;
