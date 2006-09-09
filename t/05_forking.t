use strict;
use Config;
use Test::More;

$|++; # keep stdout and stderr in order on Win32

#--------------------------------------------------------------------------#

my $class    = "t::Object::Animal";
my $subclass = "t::Object::Animal::Antelope";
my ($o, $p);


#--------------------------------------------------------------------------#

# Win32 fork is done with threads, so we need at least perl 5.8
if ( $^O eq 'MSWin32' && $Config{useithreads} &&  $] < 5.008 ) {
    plan skip_all => "Win32 fork() support requires perl 5.8";
}
else {
    plan tests => 10;
}

#--------------------------------------------------------------------------#

require_ok( $class );
require_ok( $subclass );

ok( ($o = $class->new()) && $o->isa($class),
    "Creating a $class object"
);

ok( ($p = $subclass->new()) && $p->isa($subclass),
    "Creating a $subclass object"
);

is( $o->name( "Larry" ), "Larry",
    "Setting a name for the superclass object in the parent"
);

is( $p->name( "Harry" ), "Harry",
    "Setting a name for the subclass object in the parent"
);

is( $p->color( "brown" ), "brown",
    "Setting a color for the subclass object in the parent"
);

my $child_pid = fork;
if ( ! $child_pid ) { # we're in the child
        is( $o->name, "Larry", "got right superclass object name in child");
        is( $p->name, "Harry", "got right subclass object name in child"); 
        is( $p->color, "brown", "got right subclass object name in child"); 
    exit;
}
waitpid $child_pid, 0;

# current Test::More object counter is off due to child
Test::More->builder->current_test( 10 );

