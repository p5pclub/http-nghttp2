use strict;
use warnings;
use Test::More;
use NGHTTP2::Client;

eval { require POE; POE->import; 1; }
or plan 'skip_all' => 'You need POE to run this test';

my ( $connected, @fetches );

POE::Session->create(
    inline_states => {
        '_start' => sub {
            $_[HEAP()]->{'client'} = NGHTTP2::Client->new(
                host       => 'http2bin.org',
                on_connect => sub {
                    $connected++;
                },
            );

            $_[KERNEL()]->yield('fetch');
            $_[KERNEL()]->delay('check', 0.5);
        },

        'check' => sub {
            $_[HEAP()]{'received'} == 3
                or $_[KERNEL()]->delay('check', 0.5);
        },

        'fetch' => sub {
            my $client = $_[HEAP()]{'client'};

            $client->fetch(
                path        => '/',
                method      => 'GET',
                scheme      => 'https',
                on_response => sub {
                    my ( $headers, $body ) = @_;

                    push @fetches, 1;
                    $_[HEAP()]{'received'}++;

                    $client->fetch(
                        path        => '/',
                        method      => 'GET',
                        scheme      => 'https',
                        on_response => sub {
                            my ( $headers, $body ) = @_;

                            push @fetches, 3;
                            $_[HEAP()]{'received'}++;
                        },
                    );
                },
            );

            $client->fetch(
                path        => '/',
                method      => 'GET',
                scheme      => 'https',
                on_response => sub {
                    push @fetches, 2;
                    $_[HEAP()]{'received'}++;
                },
            );
        },
    },
);

POE::Kernel->run;

is( $connected, 1, 'Connected once' );
is( $#fetches, 2, 'Received 3 responses' );
isnt( $fetches[0], 3, 'Third request is definitely not the first' );

done_testing();
