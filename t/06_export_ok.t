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

$|++; # keep stdout and stderr in order on Win32

BEGIN { use_ok( 'Class::InsideOut', qw( property register )); }

can_ok( 'main', $_ ) for @available;
