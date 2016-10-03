package NGHTTP2::Client;

use Moo;
use Carp ();
use NGHTTP2::Session;

has 'host' => (
    'is'       => 'ro',
    'isa'      => sub { ! ref $_[0] and length $_[0] },
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

sub _build_session {
    my $self    = shift;
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
    my ( $self, $path, %callbacks ) = @_;

    $self->request( $path, sub {
        my $stream = shift;

        $self->_add_stream($stream);

        $callback{'on_response'}->($stream);
    });

    return;
}

1;
