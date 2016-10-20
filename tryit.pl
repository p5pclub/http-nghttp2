use strict;
use warnings;
use NGHTTP2::Session;

my $session = NGHTTP2::Session->new({
    on_send => sub { print "inside Perl on_send\n" },
    on_recv => sub { print "inside Perl on_recv\n" },
});
$session->open_session();

# This one prints its message once
$session->recv();

# This one gets into a loop printing its message
# $session->send();
