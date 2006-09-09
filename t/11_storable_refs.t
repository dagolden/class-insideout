use strict;
use Test::More;
use Class::InsideOut ();
use Scalar::Util qw( refaddr reftype weaken isweak );

$|++; # keep stdout and stderr in order on Win32

eval { require Storable };
if ( $@ ) {
    plan skip_all => "Storable not installed",
}
else
{
    plan tests => 56; 
}

#--------------------------------------------------------------------------#
# Setup test data and variables
#--------------------------------------------------------------------------#

my $class = "t::Object::Friends";
my ($alice, $bob, $charlie);
my ($alice2, $bob2, $charlie2);
my ( $frozen, $thawed );
my @friends;

#--------------------------------------------------------------------------#
# tests
#--------------------------------------------------------------------------#

require_ok( $class );

# create the objects
ok( $alice = $class->new( { name => "Alice" } ),  
    "Creating $class object 'Alice'"
);

ok( $bob = $class->new( { name => "Bob" } ),  
    "Creating $class object 'Bob'"
);

ok( $bob->friends( $alice ),
    "Making Bob friends with Alice"
);

ok( $charlie = $class->new( { name => "Charlie" } ),  
    "Creating $class object 'charlie'"
);

ok( $charlie->friends( $alice, $bob ),
    "Making Charlie friends with Alice and Bob"
);

ok( $charlie->has_friend( $bob ),
    "Confirming 'has_friend' method works"
);

#--------------------------------------------------------------------------#
# Freezing just Bob should clone Alice
#--------------------------------------------------------------------------#

# freeze object
ok( $frozen = Storable::freeze( $bob ),
    "Freezing Bob"
);

# thaw object
ok( $bob2 = Storable::thaw( $frozen ),
    "... Thawing the frozen Bob"
);
isnt( refaddr $bob2, refaddr $bob,
    "... Thawed object is a new object"
);

# check name
is( $bob2->name(), "Bob",
    "... Thawed object is also named Bob (hereafter Bob2)"
);

# check reference copy
ok( ! $bob2->has_friend( $alice ),
    "... Bob2 is not friends with Alice"
);

is( @friends = $bob2->friends, 1,
    "... Bob2 still has 1 friend"
);

isa_ok( $friends[0], $class, 
    "... Bob2's friend"
);

is( $friends[0]->name, "Alice",
    "... Bob2's friend is also named 'Alice'"
);

#--------------------------------------------------------------------------#
# Freezing Bob and Alice together should preserve relationship
#--------------------------------------------------------------------------#

# freeze object
ok( $frozen = Storable::freeze( [ $bob, $alice ] ),
    "Freezing Bob and Alice together"
);

# thaw object
($bob2, $alice2) = @{ Storable::thaw( $frozen ) };

pass(
    "... Thawing the frozen Bob and Alice"
);

# check name
is( $bob2->name(), "Bob",
    "... One thawed object is also named Bob (hereafter Bob2)"
);

isnt( refaddr $bob2, refaddr $bob,
    "... Bob2 is not Bob"
);

is( $alice2->name(), "Alice",
    "... Other thawed object is named Alice (hereafter Alice2)"
);

isnt( refaddr $alice2, refaddr $alice,
    "... Alice2 is not Alice"
);

# check reference copy
ok( ! $bob2->has_friend( $alice ),
    "... Bob2 is not friends with Alice"
);

is( @friends = $bob2->friends, 1,
    "... Bob2 still has 1 friend"
);

is( refaddr $friends[0], refaddr $alice2,
    "... Bob2's friend is Alice2"
);

#--------------------------------------------------------------------------#
# Freezing Charlie and Bob and Alice together should preserve all 
# relationships
#--------------------------------------------------------------------------#

# freeze object
ok( $frozen = Storable::freeze( [ $charlie, $bob, $alice ] ),
    "Freezing Charlie, Bob and Alice together"
);

# thaw object
($charlie2, $bob2, $alice2) = @{ Storable::thaw( $frozen ) };

pass(
    "... Thawing the frozen Charlie, Bob and Alice"
);

# check name
is( $charlie2->name(), "Charlie",
    "... One thawed object is also named Charlie (hereafter Charlie2)"
);

isnt( refaddr $charlie2, refaddr $charlie,
    "... Charlie2 is not Charlie"
);

is( $bob2->name(), "Bob",
    "... Another thawed object is also named Bob (hereafter Bob2)"
);

isnt( refaddr $bob2, refaddr $bob,
    "... Bob2 is not Bob"
);

is( $alice2->name(), "Alice",
    "... Another thawed object is named Alice (hereafter Alice2)"
);

isnt( refaddr $alice2, refaddr $alice,
    "... Alice2 is not Alice"
);

# check reference copy
ok( ! $bob2->has_friend( $alice ),
    "... Bob2 is not friends with Alice"
);

ok( ! $charlie2->has_friend( $alice ),
    "... Charlie2 is not friends with Alice"
);

ok( ! $charlie2->has_friend( $bob ),
    "... Charlie2 is not friends with Bob"
);

is( @friends = $charlie2->friends, 2,
    "... Charlie2 still has 2 friends"
);

ok( $charlie2->has_friend( $alice2 ),
    "... Charlie2 has Alice2 as a friend"
);

ok( $charlie2->has_friend( $bob2 ),
    "... Charlie2 has Bob2 as a friend"
);

ok( $bob2->has_friend( $alice2 ),
    "... Bob2 has Alice2 as a friend"
);

#--------------------------------------------------------------------------#
# storing Alice inside herself !!
#--------------------------------------------------------------------------#

push @$alice, $alice;
weaken( $alice->[0] );
ok( isweak( $alice->[0] ),
    "Storing a weak reference to Alice inside Alice (!!)"
);

# freeze object
ok( $frozen = Storable::freeze( $alice ),
    "Freezing Alice"
);

# thaw object
ok( $alice2 = Storable::thaw( $frozen ),
    "... Thawing the frozen Alice as Alice2"
);

is( $alice2->[0], $alice2,
    "... Found Alice2 inside Alice2 (Lewis Carroll eat your heart out!)"
);

ok( ! isweak( $alice2->[0] ),
    "... Reference to Alice2 isn't weak -- limitation of Storable"
);

shift @$alice;
is( @$alice, 0,
    "Removing Alice from herself"
);

    
#--------------------------------------------------------------------------#
# let's make alice a narcissist and clone her!
#--------------------------------------------------------------------------#

ok( $alice->friends( $alice ),
    "Making Alice friends with herself (!!)"
);

# freeze object
ok( $alice2 = Storable::dclone( $alice ),
    "Cloning Alice into Alice2 (with dclone)"
);

isnt( refaddr $alice2, refaddr $alice,
    "... Alice2 is a new object"
);

# check reference copy
ok( ! $alice2->has_friend( $alice ),
    "... Alice2 is not friends with Alice"
);

ok( $alice2->has_friend( $alice2 ),
    "... Alice2 is friends with Alice2"
);

#--------------------------------------------------------------------------#
# Bilateral friendship between Alice and Bob
#--------------------------------------------------------------------------#

$alice->friends( undef );
is( scalar $alice->friends, 0,
    "Alice is no longer friends with herself (try therapy?)"
);
    
ok( $alice->friends( $bob ),
    "Making Alice friends with Bob"
);

# freeze object
ok( $alice2 = Storable::dclone( $alice ),
    "Cloning Alice into Alice2 (with dclone)"
);

ok( ! $alice2->has_friend( $bob ),
    "... Alice2 is not friends with Bob"
);

($bob2) = $alice2->friends;

is( $bob2->name, "Bob",
    "... Alice2 does have a friend named Bob (hereafter Bob2)"
);

ok( $bob2->has_friend( $alice2 ),
    "... Bob2 is friends with Alice2"
);

