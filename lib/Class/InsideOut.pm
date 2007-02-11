package Class::InsideOut;

$VERSION     = "1.05";
@ISA         = qw ( Exporter );
@EXPORT      = qw ( ); # nothing by default
@EXPORT_OK   = qw ( new id options private property public readonly register );
%EXPORT_TAGS = (
    "std"       => [ qw( id private public readonly register ) ],
    "new"       => [ qw( new ) ],
    "all"       => [ @EXPORT_OK ],
    "singleton" => [], # just a flag for import()
);

use strict;
use Carp;
use Exporter;
use Class::ISA;
use Scalar::Util qw( refaddr reftype blessed );

# Check for XS Scalar::Util with weaken() or warn and fallback
BEGIN {
    eval { Scalar::Util->import( "weaken" ) };
    if ( $@ =~ /\AWeak references/ ) {
        warn "Scalar::Util::weaken unavailable: "
           . "Class::InsideOut will not be thread-safe\n";
        *weaken = sub { shift };
    }
}

#--------------------------------------------------------------------------#
# Class data
#--------------------------------------------------------------------------#

my %PROP_DATA_FOR;      # class => { prop_name => property hashrefs }
my %PUBLIC_PROPS_FOR;   # class => { prop_name => 1 }
my %CLASS_ISA;          # class => [ list of self and @ISA tree ]
my %OPTIONS;            # class => { default accessor options  }
my %OBJECT_REGISTRY;    # refaddr => weak object reference

#--------------------------------------------------------------------------#
# option validation parameters
#--------------------------------------------------------------------------#

# Private but global so related classes can define their own valid options
# if they need them.  Modify at your own risk.  Done this way so as to 
# avoid creating class functions to do the same basic thing

use vars qw( %_OPTION_VALIDATION );

sub __coderef { ref shift eq 'CODE' or die "must be a code reference" }

%_OPTION_VALIDATION = (
    privacy => sub { 
        my $v = shift; 
        $v =~ /public|private/ or die "'$v' is not a valid privacy setting"
    },
    set_hook =>  \&__coderef,
    get_hook =>  \&__coderef,
);

#--------------------------------------------------------------------------#
# public functions
#--------------------------------------------------------------------------#

sub import {
    no strict 'refs';
    my $caller = caller;
    *{ "$caller\::DESTROY" } = _gen_DESTROY( $caller );
    # check for ":singleton" and do export attach instead of thaw
    # make ":singleton" an empty tag to Exporter doesn't choke on it
    if ( grep { $_ eq ":singleton" } @_ ) {
        *{ "$caller\::STORABLE_freeze" } = _gen_STORABLE_freeze( $caller, 1 );
        *{ "$caller\::STORABLE_attach" } = _gen_STORABLE_attach( $caller );
    }
    else {
        *{ "$caller\::STORABLE_freeze" } = _gen_STORABLE_freeze( $caller, 0 );
        *{ "$caller\::STORABLE_thaw" } = _gen_STORABLE_thaw( $caller );
    }
    goto &Exporter::import;
}

BEGIN { *id = \&Scalar::Util::refaddr; }

sub options {
    my $opt = shift;
    my $caller = caller;
    _check_options( $opt ) if defined $opt;
    return %{ $OPTIONS{ $caller } = _merge_options( $caller, $opt ) };
}
 
sub new {
    my $class = shift;
    croak "new() must be called as a class method"
        if ref $class;
    my $self = register( $class );
    return $self unless @_;
    
    # initialization
    croak "Arguments to new must be a hash or hash reference"
        if ( @_ == 1 && ! ( ref $_[0] && reftype($_[0]) eq 'HASH' ) ) 
        || ( @_ > 1 && @_ % 2 );
     
    my %args = (@_ == 1) ? %{$_[0]} : @_;

    for my $prop ( keys %args ) {
        for my $c ( _class_tree( $class ) ) {
            my $properties = $PROP_DATA_FOR{ $c };
            next unless $properties;
            if ( exists $properties->{$prop} ) {
                $properties->{$prop}{ refaddr $self } = $args{$prop};
            }
        }
    }

    return $self;
}

sub private($\%;$) {
    &_check_property;
    $_[2] ||= {};
    $_[2] = { %{$_[2]}, privacy => 'private' };
    goto &_install_property;
}

sub property($\%;$) {
    &_check_property;
    goto &_install_property;
}

sub public($\%;$) {
    &_check_property;
    $_[2] ||= {};
    $_[2] = { %{$_[2]}, privacy => 'public' };
    goto &_install_property;
}

sub readonly($\%;$) {
    &_check_property;
    $_[2] ||= {};
    $_[2] = { 
        %{$_[2]}, 
        privacy => 'public',
        set_hook => sub { die "is read-only\n" }
    };
    goto &_install_property;
}

sub register {
    my ($obj);
    if    ( @_ == 0 ) {
        # register()
        croak "Invalid call to register(): empty argument list"
    }
    elsif ( @_ == 1 ) {
        # register( OBJECT | CLASSNAME )
        if    ( blessed $_[0] ) {
            $obj = shift;
        }
        elsif ( ref \$_[0] eq 'SCALAR' ) {
            $obj = \(my $scalar);
            bless $obj, shift;
        }
        else {
            croak "Invalid argument '$_[0]' to register(): " .
                  "must be an object or class name"
        }
    }
    else {
        # register( REFERENCE/OBJECT, CLASSNAME )
        $obj = shift;
        bless $obj, shift; # ok to rebless
    }
    
    weaken( $OBJECT_REGISTRY{ refaddr $obj } = $obj );
    return $obj;
}


#--------------------------------------------------------------------------#
# private functions for implementation
#--------------------------------------------------------------------------#

# Registering is global to avoid having to register objects for each class.
# CLONE is not exported but CLONE in Class::InsideOut updates all registered
# objects for all properties across all classes

sub CLONE {
    my $class = shift;

    # assemble references to all properties for all classes
    my @properties = map { values %$_ } values %PROP_DATA_FOR;

    for my $old_id ( keys %OBJECT_REGISTRY ) {

        # retrieve the new object and id
        my $object = $OBJECT_REGISTRY{ $old_id };
        my $new_id = refaddr $object;

        # for all properties, relocate data to the new id if
        # the property has data under the old id
        for my $prop ( @properties ) {
            next unless exists $prop->{ $old_id };
            $prop->{ $new_id } = $prop->{ $old_id };
            delete $prop->{ $old_id };
        }

        # update the registry to the new, cloned object
        weaken ( $OBJECT_REGISTRY{ $new_id } = $object );
        delete $OBJECT_REGISTRY{ $old_id };
    }
}

sub _check_options{
    my ($opt) = @_;
    local $Carp::CarpLevel = $Carp::CarpLevel + 1;

    croak "Invalid options argument '$opt': must be a hash reference"
        if ref $opt ne 'HASH';

    my @valid_keys = keys %_OPTION_VALIDATION;
    for my $key ( keys %$opt ) {
        croak "Invalid option '$key': unknown option"
            if ! grep { $_ eq $key } @valid_keys;
        eval { $_OPTION_VALIDATION{$key}->( $opt->{$key} ) };
        croak "Invalid option '$key': $@" if $@;
    }
    
    return;
}

sub _check_property {
    my ($label, $hash, $opt) = @_;
    local $Carp::CarpLevel = $Carp::CarpLevel + 1;
    croak "Invalid property name '$label': must be a perl identifier"
        if $label !~ /\A[a-z_]\w*\z/;
    croak "Duplicate property name '$label'"
        if grep { $_ eq $label } keys %{ $PROP_DATA_FOR{ caller(1) } }; 
    _check_options( $opt ) if defined $opt;
    return;
}

sub _class_tree {
    my $class = shift;
    $CLASS_ISA{ $class } ||= [ Class::ISA::self_and_super_path( $class ) ];
    return @{ $CLASS_ISA{ $class } };
}

# turn object into hash -- see _revert()
sub _evert {
    my ( $obj ) = @_;
        
    # Extract properties to save
    my %property_vals;
    for my $c ( _class_tree( ref $obj) ) {
        next unless exists $PROP_DATA_FOR{ $c };
        my $properties = $PROP_DATA_FOR{ $c };
        for my $prop ( keys %$properties ) {
            my $value = exists $properties->{$prop}{ refaddr $obj }
                      ? $properties->{$prop}{ refaddr $obj }
                      : undef ;
            $property_vals{$c}{$prop} = $value;
        }
    }

    # extract object reference contents (by type)
    my $type = reftype $obj;
    my $contents = $type eq 'SCALAR' ? \do{ my $s = $$obj }
                 : $type eq 'ARRAY'  ? [ @$obj ]
                 : $type eq 'HASH'   ? { %$obj }
                 : undef    # other types not supported
                 ;

    # assemble reference to hand back
    return {
        class => ref $obj,
        type => $type,
        contents => $contents,
        properties => \%property_vals
    };
}

sub _gen_accessor {
    my ($ref) = @_;
    return sub {
        my $obj = shift;
        my $obj_id = refaddr $obj;
        $ref->{ $obj_id } = shift if (@_);
        return $ref->{ $obj_id };
    };
}
 
sub _gen_hook_accessor {
    my ($ref, $name, $get_hook, $set_hook) = @_;
    return sub {
        my ($obj,@args) = @_;
        my $obj_id = refaddr $obj;
        if (@args) {
            local *_ = \($args[0]);
            if ($set_hook) {
                eval { $set_hook->(@args) };
                if ( $@ ) { chomp $@; croak "$name() $@" }
                $ref->{ $obj_id } = shift @args;
            }
            else {
                $ref->{ $obj_id } = shift @args;
            }
        }
        elsif ($get_hook) {
            local $_ = $ref->{ $obj_id };
            my ( $value, @value );
            if ( wantarray ) {
                @value = eval { $get_hook->() };
            }
            else {
                $value = eval { $get_hook->() };
            }
            if ( $@ ) { chomp $@; croak "$name() $@" }
            return wantarray ? @value : $value;
        }
        else {
            return $ref->{ $obj_id };
        }
    };
}
 
sub _gen_DESTROY {
    my $class = shift;
    return sub {
        my $obj = shift;
        my $obj_id = refaddr $obj; # cache for later property deletes

        # Call a custom DEMOLISH hook if one exists.
        my $demolish;
        {
            no strict 'refs';
            $demolish = *{ "$class\::DEMOLISH" }{CODE};
        }
        $demolish->($obj) if defined $demolish;

        # Clean up properties in all Class::InsideOut parents
        for my $c ( _class_tree( $class ) ) {
            next unless exists $PROP_DATA_FOR{ $c };
            delete $_->{ $obj_id } for values %{ $PROP_DATA_FOR{ $c } };
        }

        # XXX this global registry could be deleted repeatedly
        # in superclasses -- SUPER::DESTROY shouldn't be called by DEMOLISH
        # it should only call SUPER::DEMOLISH if need be; still,
        # rest of the destructor doesn't need the registry, so early deletion
        # by a subclass should be safe
        delete $OBJECT_REGISTRY{ $obj_id };

        return;
    };
}

sub _gen_STORABLE_attach {
    my $class = shift;
    return sub { 
        my ( $class, $cloning, $serialized ) = @_;
        require Storable;
        my $data = Storable::thaw( $serialized );
        
        # find a user attach hook
        my $hook;
        {
            no strict 'refs';
            $hook = *{ "$class\::ATTACH" }{CODE};
        }

        # try user hook to recreate, otherwise new(), otherwise give up
        if ( defined $hook ) {
            return $hook->($class, $cloning, $data);
        }
        elsif ( $class->can( "new" ) ) {
            return $class->new();
        }
        else {
            die "Error attaching to $class:\n" .
                  "Couldn't find STORABLE_attach_hook() or new() in $class\n";
        }
    };
}
        
sub _gen_STORABLE_freeze {
    my ($class, $singleton) = @_;
    return sub {
        my ( $obj, $cloning ) = @_;

        # Call STORABLE_freeze_hooks in each class if they exists
        for my $c ( _class_tree( ref $obj ) ) {
            my $hook;
            {
                no strict 'refs';
                $hook = *{ "$c\::FREEZE" }{CODE};
            }
            $hook->($obj) if defined $hook;
        }

        # Extract properties to save
        my $data = _evert( $obj );

        if ( $singleton ) {
            # can't return refs, so freeze data as string and return
            require Storable;
            return Storable::freeze( $data );
        }
        else {
            # return $serialized, @refs
            # serialized string doesn't matter -- all data has been moved into
            # the additional ref
            return 'BOGUS', $data;
        }
    };
}

sub _gen_STORABLE_thaw {
    my $class = shift;
    return sub {
        my ( $obj, $cloning, $serialized, $data ) = @_;

        _revert( $data, $obj );

        # Call STORABLE_thaw_hooks in each class if they exists
        for my $c ( _class_tree( ref $obj ) ) {
            my $hook;
            {
                no strict 'refs';
                $hook = *{ "$c\::THAW" }{CODE};
            }
            $hook->($obj) if defined $hook;
        }

        return;
    };
}

sub _install_property{
    my ($label, $hash, $opt) = @_;

    my $caller = caller(0); # we get here via "goto", so caller(0) is right
    $PROP_DATA_FOR{ $caller }{$label} = $hash;
    my $options = _merge_options( $caller, $opt );
    if ( exists $options->{privacy} && $options->{privacy} eq 'public' ) {
        no strict 'refs';
        *{ "$caller\::$label" } =
            ($options->{set_hook} || $options->{get_hook})
                ? _gen_hook_accessor( $hash, $label, $options->{get_hook},
                                                 $options->{set_hook} )
                : _gen_accessor( $hash ) ;
        $PUBLIC_PROPS_FOR{ $caller }{ $label } = 1;
    }
    return;
}

sub _merge_options {
    my ($class, $new_options) = @_;
    my @merged;
    push @merged, %{ $OPTIONS{ $class } } if defined $OPTIONS{ $class };
    push @merged, %$new_options if defined $new_options;
    return { @merged };
}
 
sub _revert {
    my ( $data, $obj ) = @_;

    my $contents = $data->{contents};
    if ( defined $obj ) {
        # restore contents to the pregenerated object
        for ( reftype $obj ) {
            /SCALAR/    ? do { $$obj = $$contents } :
            /ARRAY/     ? do { @$obj = @$contents } :
            /HASH/      ? do { %$obj = %$contents } :
                          do {} ;
        }
    }
    else {
        # just use the contents as the reference
        # and bless it back into an object
        $obj = $contents;
    }

    bless $obj, $data->{class};

    # restore properties
    for my $c ( _class_tree( ref $obj ) ) {
        my $properties = $PROP_DATA_FOR{ $c };
        next unless $properties;
        for my $prop ( keys %$properties ) {
            my $value = $data->{properties}{ $c }{ $prop };
            $properties->{$prop}{ refaddr $obj } = $value;
        }
    }

    # register object
    register( $obj );
    return $obj;
}

#--------------------------------------------------------------------------#
# private functions for use in testing
#--------------------------------------------------------------------------#

sub _object_count {
    return scalar( keys %OBJECT_REGISTRY );
}

sub _properties {
    my $class = shift;
    my %properties;
    for my $c ( _class_tree( $class ) ) {
        next if not exists $PROP_DATA_FOR{ $c };
        for my $p ( keys %{ $PROP_DATA_FOR{ $c } } ) {
            $properties{$c}{$p} = exists $PUBLIC_PROPS_FOR{$c}{$p}
                                ? "public" : "private";
        }
    }
    return \%properties;
}

sub _leaking_memory {
    my %leaks;

    for my $class ( keys %PROP_DATA_FOR ) {
        for my $prop ( values %{ $PROP_DATA_FOR{ $class } } ) {
            for my $obj_id ( keys %$prop ) {
                $leaks{ $class }++
                    if not exists $OBJECT_REGISTRY{ $obj_id };
            }
        }
    }

    return keys %leaks;
}

1; # modules must return true
__END__

=begin wikidoc

= NAME

Class::InsideOut - a safe, simple inside-out object construction kit

= VERSION

This documentation refers to version %%VERSION%%

= SYNOPSIS

 package My::Class;
 
 use Class::InsideOut qw( public readonly private register id );

 public     name => my %name;    # accessor: name()
 readonly   ssn  => my %ssn;     # read-only accessor: ssn()
 private    age  => my %age;     # no accessor
 
 sub new { register( shift ) }
 
 sub greeting {
   my $self = shift;
   return "Hello, my name is $name{ id $self }";
 }

= DESCRIPTION

This is a simple, safe and streamlined toolkit for building inside-out objects.
Unlike most other inside-out object building modules already on CPAN, this
module aims for minimalism and robustness:

* Does not require derived classes to subclass it
* Uses no source filters, attributes or {CHECK} blocks
* Supports any underlying object type including black-box inheritance
* Does not leak memory on object destruction
* Overloading-safe
* Thread-safe for Perl 5.8 or better
* {mod_perl} compatible
* Makes no assumption about inheritance or initializer needs

It provides the minimal support necessary for creating safe inside-out objects
and generating flexible accessors.  

== Additional documentation

* [Class::InsideOut::Manual::About] -- Guide to the inside-out 
technique, the {Class::InsideOut} philosophy, and other inside-out 
implementations
* [Class::InsideOut::Manual::Advanced] -- Advanced topics including customizing
accessors, black-box inheritance, serialization and thread safety

= USAGE

== Importing {Class::InsideOut}

{Class::InsideOut} automatically imports several critical methods into the
calling package, including {DESTROY} and support methods for serializing
objects with {Storable}.  These methods are intimately tied to correct
functioning of inside-out objects and will always be imported regardless
of whether additional functions are requested. 

Additional functions may be imported as usual by including them as arguments to
{use}.  For example:

 use Class::InsideOut qw( register public );
 
 public name => my %name;
 
 sub new { register( shift ) }
 
As a shortcut, {Class::InsideOut} supports two tags for importing sets of
functions:

* {:std} provides {id}, {private}, {public}, {readonly} and {register}
* {:all} imports all functions (including an optional constructor)

*Note*: Automatic imports can be bypassed via {require} or by passing an empty
list to {use Class::InsideOut}. There is almost no circumstance in which
this is a good idea. 

== Object properties and accessors

Object properties are declared with the {public}, {readonly} and {private}
functions.  They must be passed a label and the lexical hash that will be
used to store object properties:

 public   name => my %name;
 readonly ssn  => my %ssn;
 private  age  => my %age;

Properties for an object are accessed through an index into the lexical hash
based on the memory address of the object.  This memory address ~must~ be
obtained via {Scalar::Util::refaddr}.  The alias {id} may be imported for
brevity.

 $name{ refaddr $self } = "James";
 $ssn { id      $self } = 123456789;
 $age { id      $self } = 32;

*Tip*: since {refaddr} and {id} are function calls, it may be efficient to
store the value once at the beginning of a method, particularly if it is being
called repeatedly, e.g. within a loop.

Object properties declared with {public} will have an accessor created
with the same name as the label.  If the accessor is passed an argument, the
property will be set to the argument.  The accessor always returns the value of
the property.  

 # Outside the class
 $person = My::Class->new;
 $person->name( "Larry" );

Object properties declared with {readonly} will have a read-only accessor
created.  The accessor will die if passed an argument to set the property
value.  The property may be set directly in the hash from within the class
package as usual.

 # Inside the class
 $ssn { id $person } = 987654321;
 
 # Inside or outside the class
 $person->ssn( 123456789 );      # dies

Property accessors may also be hand-written by declaring the property
{private} and writing whatever style of accessor is desired.  For example:

 sub age     { $age{ id $_[0] } }
 sub set_age { $age{ id $_[0] } = $_[1] }

Hand-written accessors will be very slightly faster as generated accessors hold
a reference to the property hash rather than accessing the property hash
directly.
 
== Object construction

{Class::InsideOut} provides no default constructor method as there are many
possible ways of constructing an inside-out object. This avoids constraining
users to any particular object initialization or superclass initialization
methodology.  

By using the memory address of the object as the index for properties, ~any~
type of reference may be used as the basis for an inside-out object with
{Class::InsideOut}.

 sub new {
   my $class = shift;
 
   my $self = \( my $scalar );    # anonymous scalar
 # my $self = {};                 # anonymous hash
 # my $self = [];                 # anonymous array
 # open my $self, "<", $filename; # filehandle reference
   
   bless $self, $class;
   register( $self );
 }

However, to ensure that the inside-out object is thread-safe, the {register}
function ~must~ be called on the newly created object.  The {register} 
function may also be called with just the class name for the common
case of blessing an anonymous scalar.

 register( $class ); # same as register( bless \(my $s), $class )

As a convenience, {Class::InsideOut} provides an optional {new} constructor
for simple objects.  This constructor automatically initializes the object
from key/value pairs passed to the constructor for all keys matching the 
name of a property (including otherwise "private" or "readonly" properties).
 
A more advanced technique for object construction uses another object, usually
a superclass object, as the object reference.  See "black-box inheritance" in
[Class::InsideOut::Manual::Advanced].

== Object destruction

{Class::InsideOut} automatically exports a special {DESTROY} function.
This function cleans up object property memory for all declared properties the
class and for all {Class::InsideOut} based classes in the {@ISA} array to
avoid memory leaks or data collision.

Additionally, if a user-supplied {DEMOLISH} function is available in the same
package, it will be called with the object being destroyed as its argument.
{DEMOLISH} can be used for custom destruction behavior such as updating class
properties, closing sockets or closing database connections.  Object properties
will not be deleted until after {DEMOLISH} returns.

 # Sample DEMOLISH: Count objects demolished (for whatever reason)
 
 my $objects_destroyed;
 
 sub DEMOLISH {
   $objects_destroyed++;
 }

{DEMOLISH} will only be called if it exists for an object's actual
class.  {DEMOLISH} will not be inherited and {DEMOLISH} will not be called
automatically for any superclasses.

{DEMOLISH} should manage any necessary calls to superclass {DEMOLISH}
methods.  As with {new}, implementation details are left to the user based on
the user's approach to object inheritance.  Depending on how the inheritance
chain is constructed and how {DEMOLISH} is being used, users may wish to
entirely override superclass {DEMOLISH} methods, rely upon {SUPER::DEMOLISH},
or may prefer to walk the entire {@ISA} tree:

 use Class::ISA;
 
 sub DEMOLISH {
   my $self = shift;
   # class specific demolish actions
 
   # DEMOLISH for all parent classes, but only once
   my @parents = Class::ISA::super_path( __PACKAGE__ );
   my %called;
   for my $p ( @parents  ) {
     my $demolish = $p->can('DEMOLISH');
     $demolish->($self) if not $called{ $demolish }++;
   }
 }

= FUNCTIONS

== {id}

 $name{ id $object } = "Larry";

This is a shorter, mnemonic alias for {Scalar::Util::refaddr}.  It returns the
memory address of an object (just like {refaddr}) as the index to access
the properties of an inside-out object.

== {new}

 My::Class->new( name => "Larry", age => 42 );

This simplistic constructor is provided as a convenience and is only exported
on request.  When called as a class method, it returns a blessed anonymous
scalar.  Arguments will be used to initialize all matching inside-out class
properties in the {@ISA} tree.  The argument may be a hash or hash reference.

== {options}

 Class::InsideOut::options( \%new_options );
 %current_options = Class::InsideOut::options();

The {options} function sets default options for use with all subsquent property
definitions for the calling package.  If called without arguments, this
function will return the options currently in effect.  When called with a hash
reference of options, these will be joined with the existing defaults,
overriding any options of the same name.

== {private}

 private weight => my %weight;
 private haircolor => my %hair_color, { %options };

This is an alias to {property} that also sets the privacy option to 'private'.
It will override default options or options passed as an argument.

== {property}

 property name => my %name;
 property rank => my %rank, { %options };

Declares an inside-out property.  Two arguments are required and a third is
optional.  The first is a label for the property; this label will be used for
introspection and generating accessors and thus must be a valid perl
identifier.  The second argument must be the lexical hash that will be used to
store data for that property.  Note that the {my} keyword can be included as
part of the argument rather than as a separate statement.  The property will be
tracked for memory cleanup during object destruction and for proper
thread-safety.

If a third, optional argument is provided, it must be a reference to a hash
of options that will be applied to the property and will override any
default options that have been set.

== {public}

 public height => my %height;
 public age => my %age, { %options };

This is an alias to {property} that also sets the privacy option to 'public'.
It will override default options or options passed as an argument.

== {readonly}

 readonly ssn => my %ssn;
 readonly fingerprint => my %fingerprint, { %options };

This is an alias to {property} that sets the privacy option to 'public' and
adds a {set_hook} option that dies if an attempt is made to use the accessor to
change the property.  It will override default options or options passed as an
argument.

== {register}

 register( bless( $object, $class ) ); # register the object 
 register( $reference, $class );       # automatic bless 
 register( $class );                   # automatic blessed scalar

Registers objects for thread-safety.  This should be called as part of a
constructor on a object blessed into the current package.  Returns the
resulting object.  When called with only a class name, {register} will bless an
anonymous scalar reference into the given class.  When called with both a
reference and a class name, {register} will bless the reference into the class.

= OPTIONS

Options customize how properties are generated.  Options may be set as a
default with the {options} function or passed as a hash reference to 
{public}, {private} or {property}.  

Valid options include:

== {privacy} 

 property rank => my %rank, { privacy => 'public' };
 property serial => my %serial, { privacy => 'private' };

If the ~privacy~ option is set to ~public~, an accessor will be created
with the same name as the label.  If the accessor is passed an argument, the
property will be set to the argument.  The accessor always returns the value of
the property.

== {get_hook}

 public list => my %list, {
     get_hook => sub { @$_ }
 };

Defines an accessor hook for when values are retrieved.  {$_} is locally
aliased to the property value for the object.  ~The return value of the hook is
passed through as the return value of the accessor.~ See "Customizing Accessors"
in [Class::InsideOut::Manual::Advanced] for details.

== {set_hook}

 public age => my %age, {
    set_hook => sub { /^\d+$/ or die "must be an integer" }
 };

Defines an accessor hook for when values are set. The hook subroutine receives
the entire argument list.  {$_} is locally aliased to the first argument for
convenience.  The property receives the value of {$_}. See "Customizing
Accessors" in [Class::InsideOut::Manual::Advanced] for details.

= SEE ALSO

Programmers seeking a more full-featured approach to inside-out objects are
encouraged to explore [Object::InsideOut].  Other implementations are also
noted in [Class::InsideOut::Manual::About].

= ROADMAP

Features slated for after the 1.0 release include:

* Adding support for [Data::Dump::Streamer] serialization hooks
* Adding additional accessor styles (e.g. get_name()/set_name())
* Further documentation revisions and clarification

= BUGS

Please report bugs or feature requests using the CPAN Request Tracker:
[http://rt.cpan.org/Public/Dist/Display.html?Name=Class-InsideOut]

When submitting a bug or request, please include a test-file or a patch to an
existing test-file that illustrates the bug or desired feature.

= AUTHOR

David A. Golden (DAGOLDEN)

dagolden@cpan.org

http://dagolden.com/

= COPYRIGHT AND LICENSE

Copyright (c) 2006, 2007 by David A. Golden

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included with
this module.

= DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=end wikidoc

