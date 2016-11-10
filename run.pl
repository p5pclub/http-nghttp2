use strict;
use warnings;
use DDP;
use NGHTTP2::Request;
use NGHTTP2::Client;

local $| = 1;

my $cv = AE::cv;

my $client = NGHTTP2::Client->new(
    host               => "10.156.56.71",
    port               => 8080,
    ":method"          => "GET",
    on_data_chunk_recv => sub {
        shift;
        print "Chunk recv: ", join( ', ', @_ ) . "\n";
        return 0;
    },
    on_header => sub {
        shift;
        print "Header: ", join( ', ', @_ ) . "\n";
        return 0;
    },
    on_stream_close => sub {
        shift;
        print "Stream close: ", join( ', ', @_ ) . "\n";
        $cv->send;
        return 0;
    },
    on_connect => sub {
        print "CONNECTED, SEND REQUEST\n";
        $_[0]->submit_request(
            NGHTTP2::Request->new(
                method    => "GET",
                scheme    => "http",
                authority => "Andrei",
                path      => "/test",
            )->finalize,
        );

        return 0;
    },
);

$cv->recv;

