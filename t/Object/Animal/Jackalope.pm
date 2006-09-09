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
private  sidekick => my %sidekick, { privacy => 'public' };

use vars qw( $freezings $thawings );

sub FREEZE {
    my $self = shift;
    $freezings++;
}

sub THAW {
    my $self = shift;
    $thawings++;
}

1;
