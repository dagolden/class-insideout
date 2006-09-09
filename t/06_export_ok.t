use strict;

my (@export_ok, @additional);

BEGIN {
    @export_ok = qw(
      options
      id
      property
      register
    );
    @additional = qw(
      DESTROY
      STORABLE_freeze
      STORABLE_thaw
    );
}

use Test::More tests =>  1 + @export_ok + @additional;

$|++; # keep stdout and stderr in order on Win32

BEGIN { use_ok( 'Class::InsideOut', @export_ok); }

can_ok( 'main', $_ ) for (@export_ok, @additional);
