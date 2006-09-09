package t::Object::Synopsis;
use strict;
 
use Class::InsideOut qw( property public private register id );
use Scalar::Util qw( refaddr );

# declare a lexical property "name" as a lexical hash
property name => my %name;

# declare a property and generate an accessor for it
property color => my %color, { privacy => 'public' };

# alias for property() with privacy => 'public'
public height => my %height;

# alias for property() with privacy => 'private'
private weight => my %weight;

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

# use 'id' as a mnemonic alias for 'refaddr'
return "Hello, my name is " . $name { id $self };
}

1;
