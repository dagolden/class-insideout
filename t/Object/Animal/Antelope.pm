package t::Object::Animal::Antelope;

use base 't::Object::Animal';

use Class::InsideOut qw( property id );

# superclass is handling new()

property color => my %color, { privacy => 'public' };

1;
