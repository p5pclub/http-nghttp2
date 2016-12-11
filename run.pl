use strict;
use warnings;
use DDP;
use NGHTTP2::Request;
use NGHTTP2::Client;

local $| = 1;

my $cv = AE::cv;

my $client = NGHTTP2::Client->new(
    host      => 'http2bin.org',
    port      => 80,
    ':method' => 'GET',

    on_frame_recv => sub {
        # XXX This doesn't run
    },

    on_data_chunk_recv => sub {
        return 0;
    },

    on_header => sub {
        return 0;
    },

    on_stream_close => sub {
        $cv->end;
        return 0;
    },

    on_done => sub {
        my ( $stream_id, $all_data ) = @_;
        print "-> $stream_id:\n"
            . "\t$all_data\n"
            . "<- $stream_id\n";
    },

    on_connect => sub {
        $cv->begin for 1 .. 2;
        $_[0]->submit_request(
            NGHTTP2::Request->new(
                method    => "GET",
                scheme    => "http",
                authority => "http2bin.org",
                path      => "/ip",
            )->finalize,
        );

        $_[0]->submit_request(
            NGHTTP2::Request->new(
                method    => "GET",
                scheme    => "http",
                authority => "http2bin.org",
                path      => "/headers",
            )->finalize,
        );

        return 0;
    },
);

$cv->recv;

