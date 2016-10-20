use strict;
use warnings;
use NGHTTP2::Session;

my $session = NGHTTP2::Session->new({
    on_send => sub { print "heya\n" },
    on_recv => sub { print "again\n" },
});

$session->recv();
$session->send();
