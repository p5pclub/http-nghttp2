package HTTP::NGHTTP2::Request;
# ABSTRACT: An HTTP::NGHTTP2 request object

use Moo;
use MooX::Types::MooseLike::Base qw< Str Int >;

has [qw<method scheme authority path>] => (
    'is'       => 'ro',
    'isa'      => Str,
    'required' => 1,
);

has 'user_agent' => (
    'is'      => 'ro',
    'isa'     => Str,
    'default' => sub {
        my $version = $HTTP::NGHTTP2::Client::VERSION || 'dev';
        return "perl/HTTP::NGHTTP2::Client/$version";
    },
);

sub finalize {
    my $self = shift;

    return [
        [ ':method'    => $self->method ],
        [ ':scheme'    => $self->scheme ],
        [ ':authority' => $self->authority ],
        [ ':path'      => $self->path ],
        [ 'user-agent' => $self->user_agent ],
    ];
}

1;
