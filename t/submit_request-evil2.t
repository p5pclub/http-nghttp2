use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../tlib";

use Test::More;
use HTTP::NGHTTP2::Session;
use HTTP::NGHTTP2::Trap;

my $buffer;
my $headers;

my $bad_val = HTTP::NGHTTP2::Trap->new(sub {
    $headers->[0][0] = "very long string that forces pv buffer to be reallocated for sure";
});

$headers = [ [ "inno"."cent", $bad_val ] ];

my $session = HTTP::NGHTTP2::Session->new({
    send => sub { $buffer .= $_[0]; length($buffer) },
});
$session->open_session();
$session->submit_request($headers);

$session->send();

is(unpack("H*", $buffer),
    "505249202a20485454502f322e300d0a0d0a534d0d0a0d0a00000d010500000001408635551c85a93f84ace641ea",
    "sent request matches");

done_testing;
