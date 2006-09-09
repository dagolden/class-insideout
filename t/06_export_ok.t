use strict;

my @available;

BEGIN {
    @available = qw(
      DESTROY
      STORABLE_freeze
      STORABLE_thaw
      property
      register
      id
    );
}

use Test::More tests =>  1 + @available ;

$|++; # keep stdout and stderr in order on Win32

BEGIN { use_ok( 'Class::InsideOut', qw( property register id )); }

can_ok( 'main', $_ ) for @available;
