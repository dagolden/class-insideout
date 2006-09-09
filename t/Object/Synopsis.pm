package t::Object::Synopsis;
use strict;

use Class::InsideOut qw( property register );
use Scalar::Util qw( refaddr );

# declare a lexical property hash with 'my'
property my %name; 

sub new {
    my $class = shift;
    my $self = \do {my $scalar};
    bless $self, $class;

    # register the object for thread-safety
    register( $self ); 
}

sub name {
    my $self = shift;
    if ( @_ ) { 

        # use 'refaddr' to access properties for an object
        $name{ refaddr $self } = shift;

        return $self;
    }
    return $name{ refaddr $self };
}

sub greeting {
    my $self = shift;
    print "Hello, my name is " . $name { refaddr $self } . "\n";
}

1;
