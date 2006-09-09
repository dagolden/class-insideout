package t::Object::Animal;
use strict;

use Class::InsideOut;
use Scalar::Util qw( refaddr );

Class::InsideOut::property name => my %name;
Class::InsideOut::property species => my %species;

# Globals for testing

our $animal_count;
our @subclass_errors;
our $freezings;
our $thawings;

sub new {
    my $class = shift;
    my $self = bless \do {my $s}, $class;
    Class::InsideOut::register($self);
    $name{ refaddr $self } = undef;
    $species{ refaddr $self } = undef;
    $animal_count++;
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


sub DEMOLISH {
    my $self = shift;
    $animal_count--;
    if ( ref $self ne "t::Object::Animal" ) {
        push @subclass_errors, ref $self;
    }
}

sub STORABLE_freeze_hook {
    my $self = shift;
    $freezings++;
}

sub STORABLE_thaw_hook {
    my $self = shift;
    $thawings++;
}

1;
