use strict;
use warnings;
use Test::More;
use Scalar::Util qw( refaddr );
use Class::InsideOut ();

$|++; # keep stdout and stderr in order on Win32 (maybe)

my %constructors_for = ( 
    't::Object::Singleton' => 'new',
    't::Object::Singleton_AltAPI' => 'get_instance',
);

# Need Storable 2.14 ( STORABLE_attach support )
eval { require Storable and Storable->VERSION( 2.14 ) };
if ( $@ ) {
    plan skip_all => "Storable >= 2.14 needed for singleton support",
}
else {
    plan tests => 11 * scalar keys %constructors_for;
}

#--------------------------------------------------------------------------#

my $name =  "Neo"; 

#--------------------------------------------------------------------------#

for my $class ( keys %constructors_for ) {
    require_ok( $class );
    my $o;
    # create the object
    my $new = $class->can( $constructors_for{$class} );
    ok( $o = $new->($class),  
        "... Creating $class object"
    );
        
    # set a name
    $o->name( $name );
    is( $o->name(), $name,
        "... Setting 'name' to '$name'"
    );
    diag refaddr $o;
        
    # freeze object
    my ( $frozen, $thawed );
    ok( $frozen = Storable::freeze( $o ),
        "... Freezing $class object"
    );

    # thaw object
    ok( $thawed = Storable::thaw( $frozen ),
        "... Thawing $class object"
    );
    is( refaddr $o, refaddr $thawed,
        "... Thawed $class object is the singleton"
    );

    # check it
    is( $thawed->name(), $name,
        "... Thawed $class object 'name' is '$name'"
    );

    # destroy the singleton
    {
        no strict 'refs';
        $thawed = undef;
        ${"$class\::self"} = undef;
        is( ${"$class\::self"}, undef,
            "... Destroying $class singleton manually"
        );
        ok( ! Class::InsideOut::_leaking_memory,
            "... $class not leaking memory"
        );
    }

    # recreate it
    ok( $thawed = Storable::thaw( $frozen ),
        "... Re-thawing $class object again (recreating)"
    );

    # check it
    is( $thawed->name(), $name,
        "... Re-thawed $class object 'name' is '$name'"
    );
}

    
        

