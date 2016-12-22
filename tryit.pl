use strict;
use warnings;

use AnyEvent;
use AnyEvent::Socket;
use NGHTTP2::Session;

my $cv = AnyEvent->condvar;
my $session;
my $recv;
my $send;

tcp_connect("http2bin.org", 80, sub {
    my $fh = shift or die "failed to connect";

    $session = NGHTTP2::Session->new({
        send => sub {
            my ($data, $flags) = @_;
            printf("# send=%s\n", unpack("h*", $data));
            return $fh->syswrite($data);
        },

        recv => sub {
            my ($length, $flags) = @_;

            print "# recv=$length: ";

            my $data;
            unless ($fh->sysread($data, $length)) {
                print "$!\n";
                return undef if $!{EAGAIN};
                die "read failed: $!\n";
            }
            printf("%s\n", unpack("h*", $data));
            return $data;
        },

        on_header => sub {
            my ($frame_type, $frame_len, $stream_id, $name, $value) = @_;
            print "[$stream_id] H: $name = $value\n";
            return 0;
        },

        on_frame_recv => sub {
            my ($frame_type, $frame_len, $stream_id) = @_;
            print "[$stream_id] F: type $frame_type, $frame_len bytes\n";
            return 0;
        },

        on_data_chunk_recv => sub {
            my ($stream_id, $flags, $data) = @_;
            print "[$stream_id] D: $data\n";
            return 0;
        },

        on_stream_close => sub {
            my ($stream_id, $error_code) = @_;
            print "[$stream_id] Closed: $error_code\n";
            $cv->end();
            return 0;
        }
    });

    $session->_ping();
    $session->open_session();

    $recv = AnyEvent->io(fh => $fh, poll => "r", cb => sub {
        $session->recv();
    });
    $send = AnyEvent->io(fh => $fh, poll => "w", cb => sub {
        $session->send();
    });

    my $stream_id;
    my $path;
    my $user_agent = "perl/NGHTTP2::Session/$NGHTTP2::Session::VERSION";

    $cv->begin();
    $path = "/ip";
    $stream_id = $session->submit_request([
        [ ":method" => "GET" ],
        [ ":scheme" => "http" ],
        [ ":authority" => "http2bin.org" ],
        [ ":path" => $path ],
        [ "user-agent" => $user_agent ],
    ]);
    printf("Submitted request for [%s] => stream_id %d\n", $path, $stream_id);

    $cv->begin();
    $path = "/stream/5";
    $stream_id = $session->submit_request([
        [ ":method" => "GET" ],
        [ ":scheme" => "http" ],
        [ ":authority" => "http2bin.org" ],
        [ ":path" => $path ],
        [ "user-agent" => $user_agent ],
    ]);
    printf("Submitted request for [%s] => stream_id %d\n", $path, $stream_id);
});

$cv->recv();
$session->close_session();
$session->_ping();
