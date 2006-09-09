package t::Object::Trivial;
use strict;
use warnings;

use Class::InsideOut;

sub new {
    my $class = shift;
    my $self = bless \do {my $s}, $class;
    Class::InsideOut::register($self);
}

1;
