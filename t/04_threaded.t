use strict;
use Config;

# threads needs to be loaded before Test::More if threads are configured
BEGIN {
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
            plan tests => 4;
        }
    }
    else {
        plan skip_all => "perl ithreads not available";
    }
}

$|++; # keep stdout and stderr in order on Win32

#--------------------------------------------------------------------------#

my $class = "t::Object::Animal";
my $o;

#--------------------------------------------------------------------------#

require_ok( $class );

ok( ($o = $class->new()) && $o->isa($class),
    "Creating a $class object"
);

is( $o->name( "Larry" ), "Larry",
    "Setting a name for the object in the parent"
);

my $thr = threads->new( 
    sub { 
        is( $o->name, "Larry", "got right name in thread") 
    } 
);

$thr->join;

