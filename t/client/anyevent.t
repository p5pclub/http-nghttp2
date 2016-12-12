use strict;
use warnings;
use Test::More 'tests' => 5;
use NGHTTP2::Client;
use NGHTTP2::Request;

eval { require AnyEvent; AnyEvent->import; 1; }
or plan 'skip_all' => 'You need AnyEvent to run this test';

my $cv = AE::cv;

my ( $data_chunk, $header );
my $client = NGHTTP2::Client->new(
    'host' => 'http2bin.org',
    'port' => 80,

    'on_connect' => sub {
        ok( 1, 'on_connect was called' );
        my $session = shift;

        $session->submit_request(
            NGHTTP2::Request->new(
                'method'    => 'GET',
                'scheme'    => 'http',
                'authority' => 'http2bin.org',
                'path'      => '/ip',
            )->finalize
        );

        return 0;
    },

    'on_header' => sub {
        $header++
            and return 0;

        ok( 1, 'on_header called at least once' );

        return 0;
    },

    'on_frame_recv' => sub {
        TODO: {
            local $TODO = 'on_frame_recv is not called';
            ok( 1, 'on_frame_recv called' );
        }

        return 0;
    },

    'on_data_chunk_recv' => sub {
        $data_chunk++
            and return 0;

        ok( 1, 'on_data_chunk_recv caclled at least once' );

        return 0;
    },

    'on_stream_close' => sub {
        ok( 1, 'Stream was closed' );

        $cv->send;

        return 0;
    },

    'on_done' => sub {
        ok( 1, 'on_done called' );

        return 0;
    },
);

$cv->recv;



__END__

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
            scheme      => 'https',
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
