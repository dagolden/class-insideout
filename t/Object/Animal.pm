package t::Object::Animal;
use strict;

use Class::InsideOut;
use Scalar::Util qw( refaddr );

Class::InsideOut::property my %name;
Class::InsideOut::property my %species;

sub new {
    my $class = shift;
    my $self = bless \do {my $s}, $class;
    Class::InsideOut::register($self);
    $name{ refaddr $self } = undef;
    $species{ refaddr $self } = undef;
    return $self;
}

sub name {
    my $self = shift;
    $name{ refaddr $self } = shift if @_;
    return $name{ refaddr $self };
}

sub species {
    my $self = shift;
    $species{ refaddr $self } = shift if @_;
    return $species{ refaddr $self };
}

1;
