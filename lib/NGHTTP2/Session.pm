package NGHTTP2::Session;
# ABSTRACT: Low-level access to the NGHTTP2 C library

use strict;
use warnings;

use XSLoader;

XSLoader::load(__PACKAGE__, $NGHTTP2::Session::VERSION);

1;

__END__

=pod

=encoding utf8

=head1 NAME

L<NGHTTP2::Session> - Perl binding for nghttp2 library

=head1 VERSION

Version 0.000003

=head1 SYNOPSIS

=head1 DESCRIPTION

This module wraps the L<https://nghttp2.org/> HTTP2 client / server library.

=head1 AUTHORS

=over 4

=item * Gonzalo Diethelm C<< gonzus AT cpan DOT org >>

=item * Sawyer X C<< xsawyerx AT cpan DOT org >>

=item * Andrei Vereha C<< avereha AT cpan DOT org >>

=item * Vickenty Fesunov C<< kent AT setattr DOT net >>

=back

=head1 THANKS

=over 4

=item * The C<Nghttp2> team at L<https://nghttp2.org/>

=back
