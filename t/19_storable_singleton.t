use strict;
use Test::More;
use Scalar::Util qw( refaddr );

$|++; # keep stdout and stderr in order on Win32 (maybe)

my @classes;
my %custom_prop_for_class;
my $prop_count;
    
# Need Storable 2.14 ( STORABLE_attach support )
eval { require Storable and Storable->VERSION( 2.14 ) };
if ( $@ ) {
    plan skip_all => "Storable >= 2.14 needed for singleton support",
}
else {
    plan tests => 7;
}

#--------------------------------------------------------------------------#

my $class = "t::Object::Singleton";
my $name =  "Neo"; 

#--------------------------------------------------------------------------#

require_ok( $class );
my $o;
# create the object
ok( $o = $class->new(),  
    "... Creating $class object"
);
    
# set a name
$o->name( $name );
is( $o->name(), $name,
    "... Setting 'name' to '$name'"
);
    
# freeze object
my ( $frozen, $thawed );
ok( $frozen = Storable::freeze( $o ),
    "... Freezing object"
);

# thaw object
ok( $thawed = Storable::thaw( $frozen ),
    "... Thawing object"
);
is( refaddr $o, refaddr $thawed,
    "... Thawed object is the singleton"
);

# check it
is( $thawed->name(), $name,
    "... Thawed object 'name' is '$name'"
);
    

