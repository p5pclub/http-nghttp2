package HTTP::NGHttp2;

use strict;
use warnings;

use XSLoader;
use parent 'Exporter';

our $VERSION = '0.000001';
XSLoader::load( 'HTTP::NGHttp2', $VERSION );

our @EXPORT_OK = qw[get_info];

1;

__END__

=pod

=encoding utf8

=head1 NAME

HTTP::NGHttp2 - TODO

=head1 VERSION

Version 0.000001

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHORS

=over 4

=item * Gonzalo Diethelm C<< gonzus AT cpan DOT org >>

=item * Sawyer X C<< xsawyerx AT cpan DOT org >>

=back
