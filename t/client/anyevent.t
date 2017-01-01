use strict;
use warnings;
use Test::More 'tests' => 6;
use HTTP::NGHTTP2::Client;
use HTTP::NGHTTP2::Request;

eval { require AnyEvent; AnyEvent->import; 1; }
or plan 'skip_all' => 'You need AnyEvent to run this test';

my $cv = AE::cv;

my ( $data_chunk, $header, $frame_recv );
my $client = HTTP::NGHTTP2::Client->new(
    'host' => 'http2bin.org',
    'port' => 80,

    'on_connect' => sub {
        ok( 1, 'on_connect was called' );
        my $session = shift;

        $session->submit_request(
            HTTP::NGHTTP2::Request->new(
                'method'    => 'GET',
                'scheme'    => 'http',
                'authority' => 'http2bin.org',
                'path'      => '/ip',
            )->finalize,
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
        $frame_recv++
            and return 0;

        ok( 1, 'on_frame_recv called' );

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
