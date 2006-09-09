package t::Object::Singleton;
use strict;

use Class::InsideOut qw( public register :singleton );

public name => my %name; 

my $self;

sub new { 
    $self ||= register( bless \(my $s), shift) 
}

1;

