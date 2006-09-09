package t::Object::Hash;
use strict;

use Class::InsideOut qw( property register id );

property name => my %name; 
property weight => my %weight;

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;

    # register the object for thread-safety
    register( $self ); 
}

sub name {
    my $self = shift;
    if ( @_ ) { 
        $name{ id $self } = shift;
        return $self;
    }
    return $name{ id $self };
}

sub weight {
    my $self = shift;
    if ( @_ ) { 
        $weight{ id $self } = shift;
        return $self;
    }
    return $weight{ id $self };
}


1;
