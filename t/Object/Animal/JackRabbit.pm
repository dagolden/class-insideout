package t::Object::Animal::JackRabbit;

use base 't::Object::Animal';

use Class::InsideOut qw( property id );

# superclass is handling new()

property speed => my %speed;

sub speed {
    my $self = shift;
    $speed{ refaddr $self } = shift if @_;
    return $speed{ refaddr $self };
}

1;
