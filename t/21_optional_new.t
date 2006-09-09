use strict;
use Test::More;

$|++; # keep stdout and stderr in order on Win32

#--------------------------------------------------------------------------#

my @cases = (
    {
        label   => q{$class->new( qw/foo/ ) croaks},
        args    => q{ qw/foo/ },
        error   => q{must be a hash or hash reference},
    },
    {
        label   => q{$class->new( qw/foo bar bam/ ) croaks},
        args    => q{ qw/foo bar bam/ },
        error   => q{must be a hash or hash reference},
    },
    {
        label   => q{$class->new( [ qw/foo bar/ ] ) croaks},
        args    => q{ [ qw/foo bar/ ] },
        error   => q{must be a hash or hash reference},
    },
);

plan tests => 10 + @cases; 

#--------------------------------------------------------------------------#

my $class = "t::Object::WithNew::Inherited";
my %properties = (
    name => "Larry",
    age  => 42,
);
my $o;

#--------------------------------------------------------------------------#
# test initialization
#--------------------------------------------------------------------------#

require_ok( $class );

can_ok( $class, 'new' );

ok( ($o = $class->new( %properties )) && $o->isa($class),
    "new( \%hash )"
);

is( $o->name(), "Larry",
    "name property initialized correctly"
);

is( $o->reveal_age, 42,
    "age property initialized correctly"
);

is( $o->t::Object::WithNew::reveal_age(), 42,
    "superclass age property initialized correctly"
);

#--------------------------------------------------------------------------#
# hash ref initializer
#--------------------------------------------------------------------------#

eval { $o = $class->new( \%properties ) };
ok( $o->isa($class), 
    'new( $hash_ref )' 
);

is( $o->name(), "Larry",
    "name property initialized correctly"
);

#--------------------------------------------------------------------------#
# hash based object initializer
#--------------------------------------------------------------------------#

eval { $o = $class->new( bless {%properties}, "Foo" ) };
ok( $o->isa($class), 
    'new( $hash_obj )' 
);

is( $o->name(), "Larry",
    "name property initialized correctly"
);

#--------------------------------------------------------------------------#
# error tests
#--------------------------------------------------------------------------#

for my $case ( @cases ) {
    eval( "$class->new( " . $case->{args} . ")" );
    like( $@, "/$case->{error}/i", "$case->{label}");
}

