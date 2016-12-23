package NGHTTP2::Client;

use Moo;
use MooX::Types::MooseLike::Base qw< Str Int HashRef CodeRef Object >;

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

# For the protocol
has [qw<on_connect on_header on_stream_close on_frame_recv on_data_chunk_recv>] => (
    'is'       => 'ro',
    'isa'      => CodeRef,
    'required' => 1,
);

# Not part of the protocol
has [qw<on_done>] => (
    'is'        => 'ro',
    'isa'       => CodeRef,
    'predicate' => 'has_on_done',
);

has 'stream_responses' => (
    'is'      => 'ro',
    'isa'     => HashRef [Int],
    'default' => sub { +{} },
);

sub get_stream_response {
    my ( $self, $stream_id ) = @_;

    exists $self->stream_responses->{$stream_id}
        or Carp::croak("Stream ID $stream_id does not exist...");

    return delete $self->stream_responses->{$stream_id};
}

sub BUILD {
    my $self = shift;

    # assert connection on initialize
    $self->connection;
}

sub _build_connection {
    my $self = shift;

    my $has_on_done      = $self->has_on_done;
    my $stream_responses = $self->stream_responses;

    Scalar::Util::weaken( my $inself = $self );
    my $guard = tcp_connect( $self->host, $self->port, sub {
        my $fh = shift or Carp::croak('Failed to connect');

        my $session;
        $session = NGHTTP2::Session->new({
            send => sub {
                my ($data, $flags) = @_;
                # debugging
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
                    return undef if $!{EAGAIN};

                    die "Unknown error: $!\n";
                }

                # debugging
                #printf( "%s\n", unpack( "h*", $data ) );

                return $data;
            },

            on_frame_recv => sub {
                my ($frame_type, $frame_len, $stream_id) = @_;
                return $inself->on_frame_recv->(
                    $session, $frame_type, $frame_len, $stream_id,
                );
            },

            on_header => sub {
                my ($frame_type, $frame_len, $stream_id, $name, $value) = @_;
                return $inself->on_header->(
                    $session, $frame_type, $frame_len, $stream_id,
                    $name, $value,
                );
            },

            on_data_chunk_recv => sub {
                my ($stream_id, $flags, $data) = @_;

                # TODO: this should be done at the caller, not here
                $has_on_done
                    and $stream_responses->{$stream_id} .= $data;

                return $inself->on_data_chunk_recv->(
                    $session, $stream_id, $flags, $data,
                );
            },

            on_stream_close => sub {
                my ($stream_id, $error_code ) = @_;

                # TODO: this should be done at the caller, not here
                # TODO: get rid of on_done
                if ($has_on_done) {
                    my $data = $self->get_stream_response($stream_id);
                    $self->on_done->( $stream_id, $data );
                }

                return $inself->on_stream_close->(
                    $session, $stream_id, $error_code
                );
            },
        });

        $session->open_session();

        $inself->set_recv_watcher(
            AnyEvent->io(
                'fh'   => $fh,
                'poll' => 'r',
                'cb'   => sub { $session->recv(); },
            )
        );

        $inself->set_send_watcher(
            AnyEvent->io(
                'fh'   => $fh,
                'poll' => 'w',
                'cb'   => sub { $session->send(); },
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
