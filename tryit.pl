use strict;
use warnings;
use NGHTTP2::Session;

my $session = NGHTTP2::Session->new({
    send => sub { print "inside Perl send\n" },
    recv => sub { print "inside Perl recv\n" },
});
$session->open_session();

# This one prints its message once
$session->recv();

# This one gets into a loop printing its message
# $session->send();
