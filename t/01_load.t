# Class::InsideOut - check module loading and create testing directory

my @api;

BEGIN {
    @api = qw(
      CLONE
      DESTROY
      property
      register
      _property_count
      _object_count
    );
}

use Test::More tests =>  1 + @api ;

BEGIN { use_ok( 'Class::InsideOut' ); }

can_ok( 'Class::InsideOut', $_ ) for @api;
