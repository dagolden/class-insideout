package t::Object::Animal::Jackalope;

use base qw( 
    t::Object::Animal::Antelope 
    t::Object::Animal::JackRabbit 
);

use Class::InsideOut qw( property id );

# superclass is handling new()

property kills => my %kills;

sub kills {
    my $self = shift;
    $kills{ refaddr $self } = shift if @_;
    return $kills{ refaddr $self };
}

1;
