package NGHTTP2::Session;
use AnyEvent;
use Moose::Role;
use Scalar::Util 'weaken';

has handle => (
    is      => 'ro',
    isa     => 'AnyEvent::Handle',
    lazy    => 1,
    builder => '_build_handle',
);

has host => (
    is        => 'ro',
    isa       => 'Str',
    predicate => 'has_host',
);

has port => (
    is      => 'Int',
    isa     => 'ro',
    default => 80,
);

has filename => (
    is        => 'Str',
    isa       => 'ro',
    predicate => 'has_filename',
);

has session => (
    is      => 'ScalarRef',
    isa     => 'ro',
    lazy    => 1,
    builder => '_build_session',
);

has max_concurrent_streams => (
    is      => 'Int',
    isa     => 'ro',
    default => 100,
);

has on_header => (
    is        => 'CodeRef',
    isa       => 'ro',
    predicate => 'has_on_header',
);

has on_frame_recv => (
    is        => 'CodeRef',
    isa       => 'ro',
    predicate => 'has_on_frame_recv',
);

has on_stream_close =>
    is        => 'CodeRef',
    isa       => 'ro',
    predicate => 'has_on_stream_close',
);

has on_data_chunk_recv => (
    is        => 'CodeRef',
    isa       => 'ro',
    predicate => 'has_on_data_chunk_recv',
);

# XXX:
# still need to bring in the loop
# all functions that call these callbacks as part of the loop should possibly
# close over the handle


sub BUILD {
    my $self = shift;
    weaken( my $inself = $self );

    # global callbacks for any session (Client or Server)

    # work the header and pass it on to a possible user callback
    NGHTTP2::nghttp2_session_callback_set_on_header_callback( sub {
        my ( $session, $frame, $name, $value, $flags, $user_data ) = @_;

        $self->has_set_header_callback
            and $self->set_header_callback(...);
    });



    # handle received frame and pass it on to a possible user callback
    NGHTTP2::nghttp2_session_callback_set_on_frame_recv_callback();

    # and the rest...
    NGHTTP2::nghttp2_session_callback_set_on_stream_close_callback();
    NGHTTP2::nghttp2_session_callback_set_on_data_chunk_recv_callback();

    # Client or Server specific stuff
    $self->session;

    # global settings for sessions
    NGHTTP2::submit_settings(...);
}

sub request {
    my ( $self, $method, $uri, $cb ) = @_;
    my $URI = URI->new($uri);

    NGHTTP2::nghttp2_submit_request(
        method    => $method,
        scheme    => $URI->scheme,
        authority => $URI->authority,
        path      => $URI->path,
    );
}

1;
