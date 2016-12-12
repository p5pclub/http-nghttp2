use strict;
use warnings;
use Test::More 'tests' => 5;
use NGHTTP2::Client;
use Scalar::Util ();

eval { require POE; POE->import; 1; }
or plan 'skip_all' => 'You need POE to run this test';

my ( $data_chunk, $header );
POE::Session->create(
    'inline_states' => {
        '_start' => sub {
            # not sure this needs to be weakened, but might as well
            Scalar::Util::weaken( my $heap = $_[ POE::Session::HEAP() ] );

            $heap->{'client'} = NGHTTP2::Client->new(
                'host'       => 'http2bin.org',
                'port'       => 80,
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

                    $heap->{'done'}++;

                    return 0;
                },

                'on_done' => sub {
                    ok( 1, 'on_done called' );

                    return 0;
                },
            );

            #$_[ POE::Session::KERNEL() ]->yield('check');
            $_[ POE::Session::KERNEL() ]->delay('check' => 0.1 );
        },

        'check' => sub {
            $_[ POE::Session::HEAP() ]->{'done'}
                or return $_[ POE::Session::KERNEL() ]->delay( 'check' => 0.1 );

            # FIXME: this doesn't actually close it...
            # Not sure what holds onto it. :/
            $_[ POE::Session::KERNEL() ]->stop();
        },
    },
);

POE::Kernel->run;
