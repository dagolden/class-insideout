package t::Object::Trivial;
use strict;
use warnings;

use Class::InsideOut;

sub new {
    return bless {};
}

1;
