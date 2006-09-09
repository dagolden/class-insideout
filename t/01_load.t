use strict;

my @api;

BEGIN {
    @api = qw(
      property
      register
      _property_count
      _object_count
      _leaking_memory
      CLONE
    );
}

use Test::More tests =>  2 + @api ;

$|++; # keep stdout and stderr in order on Win32

BEGIN { use_ok( 'Class::InsideOut' ); }

can_ok( 'Class::InsideOut', $_ ) for @api;

for ( qw( DESTROY ) ) {
    ok( ! Class::InsideOut->can( $_ ), "$_ not part of the API" );
}
    
