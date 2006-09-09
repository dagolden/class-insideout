use Test::More;
use Class::InsideOut ();

plan tests => 9;

#--------------------------------------------------------------------------#

my $class = "t::Object::Trivial";
my $o;

#--------------------------------------------------------------------------#

require_ok( $class );

is( Class::InsideOut::_property_count( "$class" ), 0,
    "$class has no properties registered"
);

is( Class::InsideOut::_object_count( $class ), 0,
    "$class has no objects registered"
);

ok( ($o = $class->new()) && $o->isa($class),
    "Creating a $class object"
);

is( Class::InsideOut::_object_count( "$class" ), 1,
    "$class has 1 object registered"
);

for ( qw( CLONE DESTROY ) ) {
    ok( $o->can($_), "Object can '$_'" );
}

undef $o;
ok( ! defined $o,
    "Destroying the object"
);

is( Class::InsideOut::_object_count( $class ), 0,
    "$class has no objects registered"
);

