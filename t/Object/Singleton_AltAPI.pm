package t::Object::Singleton_AltAPI;
use strict;
use Class::InsideOut qw( public register id :singleton );

public name => my %name; 

our $self;

sub get_instance { 
    $self ||= register( bless \(my $s), shift);
    warn "get_i: " . id $self;
    return $self;
}

sub STORABLE_attach_hook {
    my ($class, $cloning, $data) = @_;
    if ( $self ) {
        return $self;
    }
    else {
        my $obj = $class->get_instance();
        use Data::Dump::Streamer;
        $name{ id $obj } = $data->{properties}{__PACKAGE__}{name};
        warn "obj: " . id $obj;
        warn "self: " . id $self;
        warn Dump(\%name);
        return $obj;
    }
}

1;

