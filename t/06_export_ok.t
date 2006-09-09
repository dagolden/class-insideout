# Class::InsideOut - check module loading and create testing directory
use strict;

my @available;

BEGIN {
    @available = qw(
      CLONE
      DESTROY
      property
      register
    );
}

use Test::More tests =>  1 + @available ;

BEGIN { use_ok( 'Class::InsideOut', qw( property register )); }

can_ok( 'main', $_ ) for @available;
