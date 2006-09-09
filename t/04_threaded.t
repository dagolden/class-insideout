use strict;
use Config;

BEGIN {
    # don't run this at all under Devel::Cover
    if ( $ENV{HARNESS_PERL_SWITCHES} &&
         $ENV{HARNESS_PERL_SWITCHES} =~ /Devel::Cover/ ) {
        require Test::More;
        Test::More::plan( skip_all => 
            "Devel::Cover not compatible with threads" );
    }
    
    # threads needs to be loaded before Test::More if threads are configured
    if ( $Config{useithreads} ) {
        require threads;
    }
}

use Test::More;

BEGIN {
    if ( $Config{useithreads} ) {
        if( $] < 5.008 ) {
            plan skip_all => "thread support requires perl 5.8";
        }
        else {
            plan tests => 10;
        }
    }
    else {
        plan skip_all => "perl ithreads not available";
    }
}

$|++; # keep stdout and stderr in order on Win32

#--------------------------------------------------------------------------#

my $class    = "t::Object::Animal";
my $subclass = "t::Object::Animal::Antelope";
my ($o, $p);

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

my $thr = threads->new( 
    sub { 
        is( $o->name, "Larry", "got right superclass object name in thread");
        is( $p->name, "Harry", "got right subclass object name in thread"); 
        is( $p->color, "brown", "got right subclass object name in thread"); 
    } 
);

$thr->join;

