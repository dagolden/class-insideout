use strict;
local $^W = 1;
use Test::More;

# keep stdout and stderr in order on Win32

BEGIN {
    $|=1; 
    my $oldfh = select(STDERR); $| = 1; select($oldfh);
}

#--------------------------------------------------------------------------#
# option() argument cases
#--------------------------------------------------------------------------#

my @cases = (
    {
        label   => q{invalid register argument: not a reference},
        args    => q{ 'abc' },
        error   => q{invalid argument},
    },
    {
        label   => q{invalid register argument: reference not blessed},
        args    => q{ {} },
        error   => q{invalid argument},
    },
);

#--------------------------------------------------------------------------#
# Begin tests
#--------------------------------------------------------------------------#

plan tests => 1 + @cases;

require_ok( "Class::InsideOut" );

for my $case ( @cases ) {
    eval( "Class::InsideOut::register( " . $case->{args} . ")" );
    like( $@, "/$case->{error}/i", "$case->{label}");
}

