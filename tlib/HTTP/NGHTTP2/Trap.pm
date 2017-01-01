package HTTP::NGHTTP2::Trap;
use strict;
use warnings;

use overload '""' => sub {
    my $self = shift;
    $self->();
    return "poison";
};

sub new {
    my ($class, $code) = @_;
    return bless($code, $class);
}

1;
