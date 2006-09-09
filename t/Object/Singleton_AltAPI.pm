package t::Object::Singleton_AltAPI;
use strict;
use warnings;
use Class::InsideOut qw( public register id :singleton );

public name => my %name; 

our $self;

sub get_instance { 
    $self ||= register( bless \(my $s), shift) 
}

sub STORABLE_attach_hook {
    my ($class, $cloning, $data) = @_;
    if ( $self ) {
        return $self;
    }
    else {
        my $obj = $class->get_instance();
        $name{ id $obj } = $data->{properties}{__PACKAGE__}{name};
        return $obj;
    }
}

1;

