package t::Object::Animal::Jackalope;

use base qw( 
    t::Object::Animal::Antelope 
    t::Object::Animal::JackRabbit 
);

use Class::InsideOut qw( property id );

# superclass is handling new()

property kills => my %kills, { privacy => 'public' };

our $freezings;
our $thawings;

sub STORABLE_freeze_hook {
    my $self = shift;
    $freezings++;
}

sub STORABLE_thaw_hook {
    my $self = shift;
    $thawings++;
}

1;
