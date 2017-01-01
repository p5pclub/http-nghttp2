package HTTP::NGHTTP2::Session;
# ABSTRACT: Low-level access to the NGHTTP2 C library

use strict;
use warnings;

use XSLoader;

XSLoader::load(__PACKAGE__, $HTTP::NGHTTP2::Session::VERSION);

1;

__END__

=pod

=encoding utf8

=head1 SYNOPSIS

=head1 DESCRIPTION

This module wraps the L<https://nghttp2.org/> HTTP2 client / server library.

=back
