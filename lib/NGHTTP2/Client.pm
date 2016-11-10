package NGHTTP2::Client;

use Moo;
use MooX::Types::MooseLike::Base qw< Str Int CodeRef Object >;

use Carp ();
use Safe::Isa;
use Scalar::Util ();

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use NGHTTP2::Session;
use NGHTTP2::Request;

has 'host' => (
    'is'       => 'ro',
    'isa'      => Str,
    'required' => 1,
);

has 'port' => (
    'is'       => 'ro',
    'isa'      => Int,
    'required' => 1,
);

has 'send_watcher' => (
    'is'     => 'ro',
    'isa'    => Object,
    'writer' => 'set_send_watcher',
);

has 'recv_watcher' => (
    'is'     => 'ro',
    'isa'    => Object,
    'writer' => 'set_recv_watcher',
);

has 'connection' => (
    'is'      => 'ro',
    'isa'     => Object,
    'lazy'    => 1,
    'builder' => '_build_connection',
);

has 'session' => (
    'is'     => 'ro',
    'isa'    => Object,
    'writer' => 'set_session',
);

has [qw<on_connect on_header on_stream_close on_data_chunk_recv>] => (
    'is'       => 'ro',
    'isa'      => CodeRef,
    'required' => 1,
);

sub BUILD {
    my $self = shift;

    # assert connection on initialize
    $self->connection;
}

sub _build_connection {
    my $self = shift;

    Scalar::Util::weaken( my $inself = $self );
    my $guard = tcp_connect( $self->host, $self->port, sub {
        my $fh = shift or Carp::croak('failed to connect');

        my $session;
        $session = NGHTTP2::Session->new({
            send => sub {
                my ($data, $flags) = @_;
                #printf("# send=%s\n", unpack("h*", $data));
                return $fh->syswrite($data);
            },

            recv => sub {
                my ($length, $flags) = @_;

                # debugging
                #print "# recv=$length: ";

                my $data;
                if ( ! defined $fh->sysread( $data, $length ) ) {
                    # debugging
                    #print "$!\n";

                    # We're done
                    $!{'EAGAIN'}
                        and return;

                    die "Unknown error: $!\n";
                }

                # debugging
                #printf( "%s\n", unpack( "h*", $data ) );

                return $data;
            },

            on_header => sub {
                my ($frame_type, $frame_len, $stream_id, $name, $value) = @_;
                return $inself->on_header->(
                    $session, $frame_type, $stream_id, $name, $value,
                );
            },

            on_data_chunk_recv => sub {
                my ($stream_id, $flags, $data) = @_;

                return $inself->on_data_chunk_recv->(
                    $session, $stream_id, $flags, $data,
                );
            },

            on_stream_close => sub {
                my ($stream_id, $error_code ) = @_;
                return $inself->on_stream_close->(
                    $session, $stream_id, $error_code
                );
            },
        });

        $session->open_session();

        $inself->set_recv_watcher(
            AnyEvent->io(
                fh   => $fh,
                poll => "r",
                cb   => sub {
                    $session->recv();
                }
            )
        );

        $inself->set_send_watcher(
            AnyEvent->io(
                fh   => $fh,
                poll => "w",
                cb   => sub {
                    $session->send();
                }
            )
        );

        $inself->set_session($session);

        $inself->on_connect->($session);
    } );

    return $guard;
}

sub request {
    my $self = shift;
    my $request;

    if ( @_ == 1 ) {
        if ( $_[0]->$_isa('NGHTTP2::Request') ) {
            $request = $_[0];
        } else {
            Carp::croak('Bad argument to request()');
        }
    } elsif ( @_ % 2 == 0 ) {
        $request = NGHTTP2::Request->new(@_);
    } else {
        Carp::croak('Bad arguments to request()');
    }
}

1;
