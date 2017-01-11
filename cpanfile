requires 'Carp';
requires 'XSLoader';
requires 'Moo';
requires 'MooX::Types::MooseLike::Base';
requires 'Safe::Isa';
requires 'Scalar::Util';
requires 'AnyEvent';
requires 'AnyEvent::Socket';
requires 'AnyEvent::Handle';

on 'test' => sub {
    requires 'Test::More';
};

on 'develop' => sub {
    requires 'Test::LeakTrace';
    requires 'POE';
};
