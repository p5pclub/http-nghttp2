use strict;
use warnings;
use Test::More;
BEGIN { use_ok('NGHTTP2::Client') }

my $client = NGHTTP2::Client->new(
    URI => 'http://www.google.com',

    on_header => sub {
        my ( $client, $stream, ... ) = @_;
    },

    on_frame_recv => sub {
        my ( $client, $stream, ... ) = @_;
    },

    on_stream_close => sub {
        my ( $client, $stream, $data ) = @_;
    },

    on_data_chunk_recv => sub {
        my ( $client, $stream, ... ) = @_;
    },
);

my $stream_id = $client->request( 'GET', '/' );
$client->request( 'POST', '/', $body );
