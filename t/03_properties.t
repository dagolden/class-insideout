use strict;
use Test::More;
use Class::InsideOut ();

$|++; # keep stdout and stderr in order on Win32

plan tests => 12;

#--------------------------------------------------------------------------#

my $class = "t::Object::Animal";
my ($o, $p);

#--------------------------------------------------------------------------#

require_ok( $class );

is( Class::InsideOut::_property_count( "$class" ), 2,
    "$class has 2 properties registered"
);

is( Class::InsideOut::_object_count( $class ), 0,
    "$class has no objects registered"
);

ok( ($o = $class->new()) && $o->isa($class),
    "Creating a $class object"
);

ok( ($p = $class->new()) && $p->isa($class),
    "Creating another $class object"
);

is( $o->name( "Larry" ), "Larry",
    "Setting a name for the first object"
);

is( $p->name( "Damian" ), "Damian",
    "Setting a name for the second object"
);

isnt( $o->name, $p->name,
    "Objects have different names"
);

is( $o->species( "Camel" ), "Camel",
    "Setting a species for the first object"
);

undef $o;
ok( ! defined $o,
    "Destroying the first object"
);

undef $p;
ok( ! defined $p,
    "Destroying the second object"
);

ok( ! Class::InsideOut::_leaking_memory( $class ),
    "$class is not leaking memory"
);

