use strict;
use Config;
use Test::More;

#--------------------------------------------------------------------------#

my $class = "t::Object::Animal";
my $o;

#--------------------------------------------------------------------------#

# Win32 fork is done with threads, so we need at least perl 5.8
if ( $^O eq 'MSWin32' && $Config{useithreads} &&  $] < 5.008 ) {
    plan skip_all => "Win32 fork() support requires perl 5.8";
}
else {
    plan tests => 4;
}

#--------------------------------------------------------------------------#

require_ok( $class );

ok( ($o = $class->new()) && $o->isa($class),
    "Creating a $class object"
);

is( $o->name( "Larry" ), "Larry",
    "Setting a name for the object in the parent"
);

my $child_pid = fork;
if ( ! $child_pid ) { # we're in the child
    is( $o->name, "Larry", "got right name in child process");
    exit;
}
waitpid $child_pid, 0;

# current Test::More object counter is off due to child
Test::More->builder->current_test( 4 );

