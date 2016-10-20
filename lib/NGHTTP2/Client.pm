package NGHTTP2::Client;

use Moo;
use MooX::Types::MooseLike::Base qw< Int Str HashRef CodeRef >;
use Carp ();
use NGHTTP2::Session;
use AnyEvent::TLS;
use AnyEvent::Handle;
use Scalar::Util ();

use constant {
    'CALLBACKS_LIST' => [
        qw<on_connect on_error>,
        qw<on_recv on_send>,
        qw<on_header on_data_chunk_recv>,
    ],
};

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

has 'callbacks' => (
    'is'      => 'ro',
    'isa'     => HashRef [CodeRef],
    'default' => sub { return +{} },
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

sub _build_session {
    my $self    = shift;

    my $handle = AnyEvent::Handle->new(
      connect  => [$self->host, $self->port],
      tls      => "connect",
      tls_ctx  => { verify => 1, verify_peername => "https" },
      on_connect => sub {
        $self->run_callback('on_connect');
      },
      on_error => sub {
        $self->run_callback('on_error');
      }
    );

    my $session = NGHTTP2::Session->new();

    $session->open_session(
        # we put in
        on_recv => sub { $handle->recv(@_) },
        on_send => sub { $handle->send(@_) },

        # user puts in
        on_header => sub { $self->run_callback( 'on_header' => @_ ); },
        on_data_chunk_recv => sub { $self->run_callback( 'on_data' => @_ ); },
    );

    return $session;
}

sub BUILDARGS {
    my $class = shift;
    my %args;

    if ( @_ % 2 == 0 ) {
        %args = @_;
    } elsif ( ref $_[0] eq 'HASH' ) {
        %args = %{ $_[0] };
    }

    foreach my $cb_name ( @{ CALLBACKS_LIST() } ) {
        if  ( my $cb = delete $args{$cb_name} ) {
            $args{'callbacks'}{$cb_name} = $cb;
        }
    }

    return {%args};
}

sub run_callback {
    my ( $self, $callback, @args ) = @_;
    Scalar::Util::weaken( my $inself = $self );
    $self->callbacks->{$callback}->( $inself, @args );
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
