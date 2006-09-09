package t::Object::Animal::JackRabbit;

use base 't::Object::Animal';

use Class::InsideOut qw( property id );

# superclass is handling new()

property speed => my %speed, { privacy => "public" };

1;
