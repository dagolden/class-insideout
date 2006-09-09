package t::Object::Trivial;
use strict;

use Class::InsideOut;

sub new {
    my $class = shift;
    my $self = bless \do {my $s}, $class;
    Class::InsideOut::register($self);
}

1;
