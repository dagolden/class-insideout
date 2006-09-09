use strict;
use Test::More;
use Class::InsideOut ();

$|++; # keep stdout and stderr in order on Win32

plan tests => 8;

#--------------------------------------------------------------------------#

my $class = "t::Object::Animal";
my ($o, $p);

#--------------------------------------------------------------------------#

require_ok( $class );

ok( ($o = $class->new()) && $o->isa($class),
    "Creating a $class object"
);

ok( ($p = $class->new()) && $p->isa($class),
    "Creating another $class object"
);

is( $t::Object::Animal::animal_count, 2,
    "Count of animals is 2"
);

undef $o;
ok( ! defined $o,
    "Destroying the first object"
);

is( $t::Object::Animal::animal_count, 1,
    "DEMOLISH decremented the count of animals to 1"
);

undef $p;
ok( ! defined $p,
    "Destroying the second object"
);

is( $t::Object::Animal::animal_count, 0,
    "DEMOLISH decremented the count of animals to 0"
);

