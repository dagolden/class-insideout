package t::Object::Animal;
use strict;

use Class::InsideOut;
use Scalar::Util qw( refaddr );

Class::InsideOut::options(
    {
        privacy => 'public',
    }
);

Class::InsideOut::property( name => my %name );
Class::InsideOut::property( species => my %species );

# Globals for testing

use vars qw( $animal_count @subclass_errors $freezings $thawings );

sub new {
    my $class = shift;
    my $self = bless \do {my $s}, $class;
    Class::InsideOut::register($self);
    $name{ refaddr $self } = undef;
    $species{ refaddr $self } = undef;
    $animal_count++;
    return $self;
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
