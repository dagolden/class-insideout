package t::Object::Friends;
use strict;

use Class::InsideOut qw( property register id );

property name => my %name; 
property friends => my %friends;

sub new {
    my ($class, $args) = @_;
    my $self = [];
    bless $self, $class;
    # initialize from constructor
    if ( ref $args eq 'HASH' ) {
        $name   { id $self } = $args->{name};
        if ( defined $args->{friends} ) {
            if ( ref $args->{friends} eq 'ARRAY' ) {
                $friends{ id $self } = $args->{friends};
            }
            else {
                $friends{ id $self } = [ $args->{friends} ];
            }
        }
    }
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

# pass undef as first arg to clear the list
sub friends {
    my ($self, @friends) = @_;
    if ( @friends ) { 
        if ( ! defined $friends[0] ) {
            $friends{ id $self } = [];
        }
        else {
            $friends{ id $self } = [ @friends ];
        }
        return $self;
    }
    return @{ $friends{ id $self } };
}

sub has_friend {
    my ( $self, $obj ) = @_;
    return scalar grep { $_ == $obj } @{ $friends{ id $self } };
}

1;
