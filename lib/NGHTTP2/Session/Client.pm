package NGHTTP2::Session::Client;
use Carp 'croak';
use Moose;
with 'NGHTTP2::Session';

sub _build_session {
    NGHTTP2::nghttp2_session_client_new();
}

sub _build_handle {
    my $self = shift;

    # build a handle object from either:
    # * host + port
    # * unix address (same for AnyEvent)
    # * file TODO

    if ( $self->has_host ) {
        return AnyEvent::Handle->new(
            connect  => [ $self->host, $self->port ],
            on_read  => sub {},
            on_error => sub {},
            on_eof   => sub {},
        );
    }

    croak 'Must provide host/port or filename';
}

1;
