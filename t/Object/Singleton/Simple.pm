package t::Object::Singleton::Simple;
use strict;
use Class::InsideOut qw( public register :singleton );

public name => my %name; 

our $self;

sub new { 
    $self ||= register( bless \(my $s), shift);
    return $self;
}

1;

