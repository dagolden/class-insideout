package t::Object::Animal::Baboon;

use base 't::Object::Animal';

# Import DESTROY so we don't inherit it.  We want to ensure that the
# default DESTROY doesn't wind up calling DEMOLISH in the superclass
# (We get CLONE too, but we don't care.)
use Class::InsideOut;

1;
