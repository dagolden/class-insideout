package t::Object::Array;
use strict;

use Class::InsideOut qw( property register id );

property name => my %name; 
property height => my %height;

sub new {
    my $class = shift;
    my $self = [];
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

sub height {
    my $self = shift;
    if ( @_ ) { 
        $height{ id $self } = shift;
        return $self;
    }
    return $height{ id $self };
}


1;
