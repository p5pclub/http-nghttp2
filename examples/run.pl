use strict;
use warnings;
use DDP;
use HTTP::NGHTTP2::Request;
use HTTP::NGHTTP2::Client;

# Flush after every print
local $| = 1;

my $condvar = AE::cv;

my $client = HTTP::NGHTTP2::Client->new(
    host      => 'http2bin.org',
    port      => 80,

    # These callbacks are part and parcel of the protocol.
    # We simply print the values, so that the flow becomes obvious.

    on_frame_recv => sub {
        my ($session, $frame_type, $frame_len, $stream_id) = @_;
        print "on_frame_recv => [$frame_type, $frame_len, $stream_id]\n";
        return 0;
    },

    on_header => sub {
        my ($session, $frame_type, $frame_len, $stream_id, $name, $value) = @_;
        print "on_header => [$frame_type, $frame_len, $stream_id, $name = $value]\n";
        return 0;
    },

    on_data_chunk_recv => sub {
        my ($session, $stream_id, $flags, $data) = @_;
        print "on_data_chunk_recv => [$stream_id, $flags, $data]\n";
        return 0;
    },

    on_stream_close => sub {
        my ($session, $stream_id, $error_code) = @_;
        print "on_stream_close => [$stream_id, $error_code]\n";

        # Once a stream closes, we notify the condvar that there is
        # one thing less to wait on (see on_connect).
        $condvar->end;

        return 0;
    },

    # These callbacks are "higher-level": they exist so tha you can plug your
    # own functionality. The library arranges for these to be called at the
    # appropriate times.
    on_connect => sub {
        my ($session) = @_;
        print "Connected!\n";

        # Once we are connected, we submit two simultaneous
        # requests. Each request will signal $condvar once the
        # corresponding reply is received (see on_stream_close).
        my @paths = qw{ /ip /headers };
        my %args = (
            method    => "GET",
            scheme    => "http",
            authority => "http2bin.org",
        );
        $condvar->begin for @paths;
        foreach my $path (@paths) {
            my $stream_id = $session->submit_request(
                HTTP::NGHTTP2::Request->new( %args, path => $path)->finalize
            );
            print "Submitted request for $path => stream id $stream_id\n";
        }

        return 0;
    },

    on_done => sub {
        my ($stream_id, $all_data) = @_;

        print "Got reply:\n"
            . ">>> $stream_id >>>\n"
            . $all_data
            . "<<< $stream_id <<<\n";
    },
);

print "Waiting for all requests to complete...\n";
$condvar->recv;
print "All requests completed, bye\n";

