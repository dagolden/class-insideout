package t::Object::Foreign;
use strict;

use Class::InsideOut qw( register property id );
use base 'IO::File';

property my %name;

sub new {
    my ($class, $filename) = @_;
    my $self = IO::File->new( $filename );
    register( bless $self, $class );
}

sub name {
    my $self = shift;
    $name{ id $self } = shift if @_;
    return $name{ id $self };
}

1;
