package t::Object::Animal::Jackalope;

use base qw( 
    t::Object::Animal::Antelope 
    t::Object::Animal::JackRabbit 
);

use Class::InsideOut qw( private property id );

# superclass is handling new()

Class::InsideOut::options( { privacy => 'public' } );

property kills    => my %kills;
private  whiskers => my %whiskers; 

use vars qw( $freezings $thawings );

sub STORABLE_freeze_hook {
    my $self = shift;
    $freezings++;
}

sub STORABLE_thaw_hook {
    my $self = shift;
    $thawings++;
}

1;
