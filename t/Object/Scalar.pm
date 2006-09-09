package t::Object::Scalar;
use strict;

use Class::InsideOut qw( property register id );

property name => my %name; 
property age => my %age;

sub new {
    my $class = shift;
    my $self = \do {my $scalar};
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

sub age {
    my $self = shift;
    if ( @_ ) { 
        $age{ id $self } = shift;
        return $self;
    }
    return $age{ id $self };
}


1;
