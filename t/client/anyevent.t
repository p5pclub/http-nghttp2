use strict;
use warnings;
use Test::More;
use AnyEvent;
use NGHTTP2::Client;

my $cv = AE::cv;

my ( $connected, @fetches );
my $client = NGHTTP2::Client->new(
    scheme     => 'https',
    host       => 'http2bin.org',
    on_connect => sub {
        $connected++;
    },
);

$cv->begin for 1 .. 3;

$client->fetch(
    path        => '/',
    method      => 'GET',
    on_response => sub {
        my ( $headers, $body ) = @_;

        push @fetches, 1;
        $cv->end;

        $client->fetch(
            path        => '/',
            method      => 'GET',
            on_response => sub {
                my ( $headers, $body ) = @_;

                push @fetches, 3;
                $cv->end;
            },
        );
    },
);

$client->fetch(
    path        => '/',
    method      => 'GET',
    on_response => sub {
        push @fetches, 2;
        $cv->end;
    },
);

$cv->recv;

is( $connected, 1, 'Connected once' );
is( $#fetches, 2, 'Received 3 responses' );
isnt( $fetches[0], 3, 'Third request is definitely not the first' );

done_testing();
