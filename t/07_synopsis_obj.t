use strict;
use Test::More;
use Class::InsideOut ();

$|++; # keep stdout and stderr in order on Win32

plan tests => 12;

#--------------------------------------------------------------------------#

my $class = "t::Object::Synopsis";
my ($o, $p);

#--------------------------------------------------------------------------#

require_ok( $class );

is_deeply( [ sort( Class::InsideOut::_properties( "$class" ) ) ], 
           [ sort( qw( name color height weight ) ) ],
    "$class has 4 properties registered"
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

$o->name( "Larry" );
is( $o->name(), "Larry",
    "Setting a name for the first object"
);

$p->name( "Damian" );
is( $p->name(), "Damian",
    "Setting a name for the second object"
);

isnt( $o->name, $p->name,
    "Objects have different names"
);

is( $o->greeting, "Hello, my name is Larry",
    "Object greeting correct"
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

