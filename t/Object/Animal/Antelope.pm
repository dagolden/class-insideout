package t::Object::Animal::Antelope;

use base 't::Object::Animal';

use Class::InsideOut qw( property id );

# superclass is handling new()

property color => my %color;

sub color {
    my $self = shift;
    $color{ refaddr $self } = shift if @_;
    return $color{ refaddr $self };
}

1;
