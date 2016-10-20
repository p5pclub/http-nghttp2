package NGHTTP2::Client;

use Moo;
use MooX::Types::MooseLike::Base qw< Int Str >;
use Carp ();
use NGHTTP2::Session;

has 'host' => (
    'is'       => 'ro',
    'isa'      => Str,
    'required' => 1,
);

has 'scheme' => (
    'is'  => 'ro',
    'isa' => sub {
        !ref $_[0] && length $_[0] && $_[0] eq 'http'
            or $_[0] eq 'https';
    },
    'default' => sub { return 'https' },
);

has 'port' => (
    'is'       => 'ro',
    'isa'      => Int,
    'default'  => 443,
    'required' => 1,
);

has 'on_connect' => (
    'is'       => 'ro',
    'isa' =>
        sub { ref $_[0] eq 'CODE' or Carp::croak("$_[0] must be coderef"); },
    'required' => 1,
);

has 'session' => (
    'is'      => 'ro',
    'lazy'    => 1,
    'builder' => '_build_session',
);

has 'streams' => (
    'is'      => 'ro',
    'default' => sub { +{} },
);

use AnyEvent::TLS;
use AnyEvent::Handle;

sub _build_session {
    my $self    = shift;

    my $handle = new AnyEvent::Handle(
      connect  => [$self->host, $self->port],
      tls      => "connect",
      tls_ctx  => { verify => 1, verify_peername => "https" },
      on_connect => sub {
        $self->on_connect->();
      },
      on_error => sub {
        $self->on_error->();
      }
    );

    my $session = NGHTTP2::Session->new();

    $session->open_session( sub {
        $self->on_connect->();
    });

    return $session;
}

sub _add_stream {
    my ( $self, $stream_id ) = @_;
    return $self->{'streams'}{$stream_id} = 1;
}

## XXX: Not used yet
## no critic qw(Subroutines::ProhibitUnusedPrivateSubroutines)
sub _remove_stream {
    my ( $self, $stream_id ) = @_;
    return delete $self->{'streams'}{$stream_id};
}

sub DEMOLISH {
    my $self    = shift;
    my $session = $self->session;

    $session->close_session();
    $session->terminate_session();

    return;
}

sub fetch {
    my ( $self, %options ) = @_;

    $self->request( $options{'path'}, sub {
        my ( $stream, $headers, $body ) = @_;

        $self->_add_stream($stream);

        $options{'on_response'}->( $headers, $body );
    });

    return;
}

1;
