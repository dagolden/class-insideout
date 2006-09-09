use strict;
use Test::More;
use Class::InsideOut ();

$|++; # keep stdout and stderr in order on Win32

plan tests => 11;

#--------------------------------------------------------------------------#

my $class = "t::Object::Trivial";
my ($o, $p);

#--------------------------------------------------------------------------#

require_ok( $class );

is_deeply( Class::InsideOut::_properties( "$class" ) , {},
    "$class has no properties registered"
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

is( Class::InsideOut::_object_count( "$class" ), 2,
    "$class has 2 objects registered"
);

for ( qw( DESTROY ) ) {
    ok( $o->can($_), "Object can '$_'" );
}

undef $o;
ok( ! defined $o,
    "Destroying the first object"
);

is( Class::InsideOut::_object_count( $class ), 1,
    "$class has 1 object registered"
);

undef $p;
ok( ! defined $p,
    "Destroying the second object"
);

is( Class::InsideOut::_object_count( $class ), 0,
    "$class has no objects registered"
);


