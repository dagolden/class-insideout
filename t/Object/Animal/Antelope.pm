package t::Object::Animal::Antelope;

use base 't::Object::Animal';

use Class::InsideOut qw( property public id );

# superclass is handling new()

Class::InsideOut::options( { privacy => 'private' } );

# should override default options above
property color => my %color, { privacy => 'public' };

# should override default 
public   points => my %points;

1;
