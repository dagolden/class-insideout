use strict;
use Test::More;
use Class::InsideOut ();

$|++; # keep stdout and stderr in order on Win32

plan tests => 15;

#--------------------------------------------------------------------------#

my $class = "t::Object::Animal::Jackalope";

# sort alpha
my $properties = {
    "t::Object::Animal" => {
        name    => "public",
        species => "public",
    },
    "t::Object::Animal::Antelope" => {
       color    => "public",
       panicked => "private",
       points   => "public",
    },
    "t::Object::Animal::JackRabbit" => {
       speed    => "public",
    },
    "t::Object::Animal::Jackalope" => {
       kills    => "public",
       sidekick => "private",
       whiskers => "private",
    },
};

my ($o, $p);

#--------------------------------------------------------------------------#

require_ok( $class );

is_deeply( Class::InsideOut::_properties( $class ), 
           $properties,
    "$class has/inherited its expected properties"
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

is( $o->color( "brown" ), "brown",
    "Setting a color for the first object"
);

is( $o->speed( "42" ), "42",
    "Setting a speed for the first object"
);

is( $o->points( 13 ), 13,
    "Setting points for the first object"
);

is( $p->kills( "23" ), "23",
    "Setting a kill-count for the second object"
);

undef $o;
ok( ! defined $o,
    "Destroying the first object"
);

undef $p;
ok( ! defined $p,
    "Destroying the second object"
);

my @leaks = Class::InsideOut::_leaking_memory;
is( scalar @leaks, 0, 
    "$class is not leaking memory"
) or diag "Leaks detected in:\n" . join( "\n", map { q{  } . $_ } @leaks );

