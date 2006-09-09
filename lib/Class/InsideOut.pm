package Class::InsideOut;

$VERSION     = "0.13";
@ISA         = qw ( Exporter );
@EXPORT      = qw ( ); # nothing by default
@EXPORT_OK   = qw ( id options private property public register );
%EXPORT_TAGS = (
    "std"  => [ qw( id private public register ) ],
    "all"  => [ @EXPORT_OK ],
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

my %PROP_DATA_FOR;      # class => [ list of property hashrefs ]
my %PROP_NAMES_FOR;     # class => [ matching list of names ]
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
    *{ "$caller\::STORABLE_freeze" } = _gen_STORABLE_freeze( $caller );
    *{ "$caller\::STORABLE_thaw" } = _gen_STORABLE_thaw( $caller );
    goto &Exporter::import;
}

BEGIN { *id = \&Scalar::Util::refaddr; }

sub options {
    my $opt = shift;
    my $caller = caller;
    _check_options( $opt ) if defined $opt;
    return %{ $OPTIONS{ $caller } = _merge_options( $caller, $opt ) };
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

sub register {
    my $obj = shift;
    croak "Invalid argument '$obj' to register(): must be blessed reference"
        if ! blessed $obj;
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
    my @properties = map { @$_ } values %PROP_DATA_FOR;

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
        if $opt && ref $opt ne 'HASH';

    my @valid_keys = keys %_OPTION_VALIDATION;
    for my $key ( keys %$opt ) {
        croak "Invalid option '$key': unknown option"
            if ! grep { $_ eq $key } @valid_keys;
        if ( ref $_OPTION_VALIDATION{$key} eq 'CODE' ) {
            eval { $_OPTION_VALIDATION{$key}->( $opt->{$key} ) };
            croak "Invalid option '$key': $@" if $@;
        }
    }
    
    return;
}

sub _check_property {
    my ($label, $hash, $opt) = @_;
    local $Carp::CarpLevel = $Carp::CarpLevel + 1;
    croak "Invalid property name '$label': must be a perl identifier"
        if $label !~ /\A[a-z_]\w*\z/;
    croak "Duplicate property name '$label'"
        if grep /$label/, @{ $PROP_NAMES_FOR{ caller(1) } }; 
    _check_options( $opt ) if defined $opt;
    return;
}

sub _class_tree {
    my $class = shift;
    $CLASS_ISA{ $class } ||= [ Class::ISA::self_and_super_path( $class ) ];
    return @{ $CLASS_ISA{ $class } };
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
                if ( $@ ) { croak "Argument to $name() $@" }
                $ref->{ $obj_id } = shift @args;
            }
            else {
                $ref->{ $obj_id } = shift @args;
            }
        }
        if ($get_hook) {
            local $_ = $ref->{ $obj_id };
            return $get_hook->();
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
            delete $_->{ $obj_id } for @{ $PROP_DATA_FOR{ $c } };
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

sub _gen_STORABLE_freeze {
    my $class = shift;
    return sub {
        my ( $obj, $cloning ) = @_;

        # Setup inheritance array
        my @class_isa = _class_tree( $class );

        # Call STORABLE_freeze_hooks in each class if they exists
        for my $c ( @class_isa ) {
            my $hook;
            {
                no strict 'refs';
                $hook = *{ "$c\::STORABLE_freeze_hook" }{CODE};
            }
            $hook->($obj) if defined $hook;
        }

        # Extract properties to save
        my %property_vals;
        for my $c ( @class_isa ) {
            next unless exists $PROP_DATA_FOR{ $c };
            my $properties = $PROP_DATA_FOR{ $c };
            for my $prop ( @$properties ) {
                my $value = exists $prop->{ refaddr $obj }
                          ? $prop->{ refaddr $obj }
                          : undef ;
                push @{ $property_vals{$c} }, $value;
            }
        }

        # extract object reference contents (by type)
        my $type = reftype $obj;
        my $contents = $type eq 'SCALAR' ? \do{ my $s = $$obj }
                     : $type eq 'ARRAY'  ? [ @$obj ]
                     : $type eq 'HASH'   ? { %$obj }
                     : undef
                     ;
 
        # assemble reference to hand back to Storable
        my $data = {
            contents => $contents,
            properties => \%property_vals
        };

        # return $serialized, @refs
        # serialized string doesn't matter -- all data has been moved into
        # the additional ref
        return 'BOGUS', $data;
    };
}

sub _gen_STORABLE_thaw {
    my $class = shift;
    return sub {
        my ( $obj, $cloning, $serialized, $data ) = @_;

        # Setup inheritance array
        my @class_isa = _class_tree( $class );

        # restore contents
        my $contents = $data->{contents};
        my $type = reftype $obj;
        if    ( $type eq 'SCALAR' ) { $$obj = $$contents }
        elsif ( $type eq 'ARRAY'  ) { @$obj = @$contents }
        elsif ( $type eq 'HASH'   ) { %$obj = %$contents }
        else                        { } # leave it empty
 
        # restore properties
        for my $c ( @class_isa ) {
            my $properties = $PROP_DATA_FOR{ $c };
            my @property_vals = @{ $data->{properties}{ $c } };
            for my $prop ( @$properties ) {
                $prop->{ refaddr $obj } = shift @property_vals;
            }
        }

        # Call STORABLE_thaw_hooks in each class if they exists
        for my $c ( @class_isa ) {
            my $hook;
            {
                no strict 'refs';
                $hook = *{ "$c\::STORABLE_thaw_hook" }{CODE};
            }
            $hook->($obj) if defined $hook;
        }

        return;
    };
}

sub _install_property{
    my ($label, $hash, $opt) = @_;

    my $caller = caller(0); # we get here via "goto", so caller(0) is right
    push @{ $PROP_NAMES_FOR{ $caller } }, $label;
    push @{ $PROP_DATA_FOR{ $caller } }, $hash;
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
        next if not exists $PROP_NAMES_FOR{ $c };
        for my $p ( @{ $PROP_NAMES_FOR{ $c } } ) {
            $properties{$c}{$p} = exists $PUBLIC_PROPS_FOR{$c}{$p}
                                ? "public" : "private";
        }
    }
    return \%properties;
}

sub _leaking_memory {
    my %leaks;

    for my $class ( keys %PROP_DATA_FOR ) {
        for my $prop ( @{ $PROP_DATA_FOR{ $class } } ) {
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

= SYNOPSIS

 package My::Class;
 
 use Class::InsideOut ':std'; # public, private, register and id

 public     name => my %name;       # accessor: name()
 private    ssn  => my %ssn;        # no accessor
 
 public     age  => my %age, {
    set_hook => sub { /^\d+$/ or die "must be an integer" }
 };
 
 public     initials => my %initials, {
    set_hook => sub { $_ = uc $_ }
 };

 sub new {
   register( bless \(my $s), shift );
 }
 
 sub greeting {
   my $self = shift;
   return "Hello, my name is $name{ id $self }";
 }

= LIMITATIONS AND ROADMAP

This is an *alpha release* for a work in progress. It is functional but
unfinished and should not be used for any production purpose.  It has been
released to solicit peer review and feedback.

Serialization with [Storable] appears to be working but may have unanticipated
bugs if an object contains a complicated (i.e. circular) reference structure
and could use some real-world testing.

I believe API's may have stabilized.  The module will be declared "beta" when
additional accessor styles are written and singleton support for Storable has
been added.  Users' feedback would be greatly appreciated.

= DESCRIPTION

This is a simple, safe and streamlined toolkit for building inside-out objects.
Unlike most other inside-out object building modules already on CPAN, this
module aims for minimalism and robustness.  It does not require derived classes
to subclass it; uses no source filters, attributes or CHECK blocks; supports
any underlying object type including foreign inheritance; does not leak memory;
is overloading-safe; is thread-safe for Perl 5.8 or better; and should be
mod_perl compatible.

It provides the minimal support necessary for creating safe inside-out objects
and generating flexible accessors.  All other implementation details,
including writing a constructor and managing inheritance, are left to the user
to maximize flexibility.

Programmers seeking a more full-featured approach to inside-out objects are
encouraged to explore [Object::InsideOut].  Other implementations are briefly
noted in the [/"SEE ALSO"] section.

== Inside-out object basics

Inside-out objects use the blessed reference as an index into lexical data
structures holding object properties, rather than using the blessed reference
itself as a data structure.

 $self->{ name }        = "Larry"; # classic, hash-based object
 $name{ refaddr $self } = "Larry"; # inside-out

The inside-out approach offers three major benefits:

* Enforced encapsulation: object properties cannot be accessed directly
from ouside the lexical scope that declared them
* Making the property name part of a lexical variable rather than a hash-key
means that typos in the name will be caught as compile-time errors (if
using [strict])
* If the memory address of the blessed reference is used as the index,
the reference can be of any type

In exchange for these benefits, however, robust implementation of inside-out
objects can be quite complex.  {Class::InsideOut} manages that complexity.

== Philosophy of {Class::InsideOut}

{Class::InsideOut} provides a set of tools for building safe inside-out classes
with maximum flexibility.

It aims to offer minimal restrictions beyond those necessary for robustness of
the inside-out technique.  All capabilities necessary for robustness should be
automatic.  Anything that can be optional should be.  The design should not
introduce new restrictions unrelated to inside-out objects (such as attributes
and {CHECK} blocks that cause problems for {mod_perl} or the use of source
filters for a new syntax).

As a result, only a few things are mandatory:

* Properties must be based on hashes and declared via {property}
* Property hashes must be keyed on the {Scalar::Util::refaddr} of the object
(or the optional {id} alias to {Scalar::Util::refaddr}).
* {register} must be called on all new objects

All other implementation details, including constructors, initializers and
class inheritance management are left to the user.  This does requires some
additional work, but maximizes freedom.  {Class::InsideOut} is intended to
be a base class providing only fundamental features.  Subclasses of
{Class::InsideOut} could be written that build upon it to provide particular
styles of constructor, destructor and inheritance support.

= USAGE

== Importing {Class::InsideOut}

 use Class::InsideOut;

No functions are imported by default -- all functions must be called using
their fully qualified names:

 Class::InsideOut::property name => my %name;
 Class::InsideOut::register $self;

Functions can be imported by including them as arguments with {use}. For
example:

 use Class::InsideOut qw( register property );

 property name => my %name;
 register $self;

As a shortcut, {Class::InsideOut} supports two tags for importing sets of
functions:

 use Class::InsideOut ':std'; # id, private, public, register
 
 use Class::InsideoUT ':all'; # all functions

In addition, {Class::InsideOut} automatically imports three critical methods
into the namespace that uses it: {DESTROY}, {STORABLE_freeze} and
{STORABLE_thaw}.  These methods are intimately tied to correct functioning of
the inside-out objects.  They will be imported regardless of whether or not any
other functions are requested with {use}.  This can only be avoided by
explicitly doing no importing, either via {require} or passing an empty list to
{use}:

 use Class::InsideOut ();

There is almost no circumstance under which this is a good idea.  See
[/"Object destruction"] and [/"Serialization"] for how to add customized
behavior to these methods.

== Object properties

Object properties are declared with the {property} function (or its special
aliases {public} and {private}), which must be passed a label and a lexical
(i.e. {my}) hash.

 property name => my %name;
 property age => my %age;

Properties are private by default and no accessors are created.  Users are
free to create accessors of any style.  See [/"Property accessors"] for
how to have {Class::InsideOut} automatically generate accessors.

Properties for an object are accessed through an index into the lexical hash
based on the memory address of the object.  This memory address ~must~ be
obtained via {Scalar::Util::refaddr}.  The alias {id} is available for
brevity.

 $name{ refaddr $self } = "James";
 $age { id      $self } = 32;

*Tip*: since {refaddr} (or {id}) are function calls, it may be helpful
to store the value once at the beginning of a method rather than call it
repeatedly throughout.  This is particularly true if it would be called
within a loop.  For example:

 property dsn => my %dsn;
 property dbh => my %dbh;
 
 sub dbi_connect {
     my $self = shift;
     my $id = refaddr $self; # calculate once and store

     # try up to 20 times
     for ( 1 .. 20 ) {
         $dbh{ $id } = DBI->connect( $dsn{ $id } );
         return if $dbh{ $id };
     }
     die "Couldn't connect to $dsn{ $id }";
 }

== Property accessors

 property color => my %color, { privacy => 'public' };
 
 $obj->color( "red" );
 print $obj->color(); # prints "red"

The {property} method supports an optional hash reference of options.  If the
~privacy~ option is equal to ~public~, an accessor will be created with the
same name as the label.  If the accessor is passed an argument, the property
will be set to the argument.  The accessor always returns the value of the
property.  Future versions of {Class::InsideOut} will support additional
accessor styles.

Default accessor options may be set using the {options} function and will
affect all subsequent calls to {property}.

{Class::InsideOut} offers two aliases for {property} that additionally
set the privacy property accordingly, overriding the defaults and any options
provided:

 public  height => my %height;
 private weight => my %weight;

See the documentation of each for details.

*Tip*: generated accessors will be very slightly slower than a hand-rolled one
as the generated accessor holds a reference rather than accessing the lexical
property hash directly.
 
== Accessor hooks

{Class::InsideOut} supports custom subroutine hooks to modify the behavior of
accessors.  Hooks are passed as property options: {set_hook} and {get_hook}.

The {set_hook} option is called when the accessor is called with an argument.
The hook subroutine receives the entire argument list.  Just before the hook is
called, {$_} is locally aliased to the first argument for convenience.

 public age => my %age, {
    set_hook => sub { /^\d+$/ or die "must be an integer" }
 };

If the {set_hook} dies, the error is caught and rethrown with a preamble that
includes the name of the accessor:

 $obj->age(3.5); # dies with "Argument to age() must be an integer at..."

When the {set_hook} returns, the property is set equal to {$_}.  This feature
is useful for on-the-fly modification of the value that will be stored.

 public list => my %list, {
    set_hook => sub { $_ = [ @_ ] } # stores arguments in a reference
 };

~Note that the return value of the {set_hook} is ignored.~  (This simplifies syntax in
the more frequent case of validating input versus modifying input.)

The {get_hook} option is called when the accessor is called without an
argument.  Just before the hook is called, {$_} is set equal to the property
value of the object for convenience. The hook is called in the same context
(i.e. list versus scalar) as the accessor.  ~The return value of the hook is
passed through as the return value of the accessor.~  

 public list => my %list, {
    set_hook => sub { $_ = [ @_ ] }, # stores arguments in a reference
    get_hook => sub { @$_ }          # return property as a list
 };

Because {$_} is a copy, not an alias, of the property value, it
can be modified directly, if necessary, without affecting the underlying
property.

Accessor hooks can be set as a global default with the {options} function,
though they may still be overridden with options passed to specific properties.

== Object construction

{Class::InsideOut} provides no constructor method as there are many possible
ways of constructing an inside-out object.  Additionally, this avoids
constraining users to any particular object initialization or superclass
initialization approach.

By using the memory address of the object as the index for properties, ~any~
type of reference can be used as the basis for an inside-out object with
{Class::InsideOut}.

 sub new {
   my $class = shift;
 
   my $self = \( my $scalar );  # anonymous scalar
 # my $self = {};                 # anonymous hash
 # my $self = [];                 # anonymous array
 # open my $self, "<", $filename; # filehandle reference
 
   register( bless $self, $class );
 }

However, to ensure that the inside-out objects are thread-safe, the {register}
function ~must~ be called on the newly created object.  See [/register] for
details.

A more advanced technique uses another object, usually a superclass object,
as the object reference.  See [/"Foreign inheritance"] for details.

== Object destruction

{Class::InsideOut} automatically exports a customized {DESTROY} function.
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

{DEMOLISH} will only be automatically called if it exists for an object's
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
   my @demolishers = map { $_->can("DEMOLISH") }
                         Class::ISA::super_path( __PACKAGE__ );
   for my $d ( @demolishers  ) {
     $d->($self) if $d;
   }
 }

Generally, any class that inherits from another should define its own
{DEMOLISH} method.

== Foreign inheritance

Because inside-out objects built with {Class::InsideOut} can use any type of
reference for the object, inside-out objects can be built using other objects.
This is useful to extend a superclass without regard for whether the superclass
implement objects with a hash or array or other reference.

 use base 'IO::File';
 
 sub new {
   my ($class, $filename) = @_;
 
   my $self = IO::File->new( $filename );
 
   register( bless $self, $class );
 }

In the example above, {IO::File} is a superclass.  The object is an
{IO::File} object, re-blessed into the inside-out class.  The resulting
object can be used directly anywhere an {IO::File} object would be,
without interfering with any of its own inside-out functionality.

Classes using foreign inheritance should provide a {DEMOLISH} function that
calls the foreign class destructor explicitly.

== Serialization

{Class::InsideOut} has support for serialization with [Storable] by providing
the {STORABLE_freeze} and {STORABLE_thaw} methods.  {Storable} will use these
methods to serialize.  They should not be called directly.  Due to limitations
of {Storable}, this serialization will only work for objects based on scalars,
arrays or hashes.

References to object within the object being frozen will result in clones
upon thawing unless the other references are included in the same freeze
operation.  (See {Storable} for details.)

  # assume $alice and $bob are objects
  $alice->friends( $bob );
  $bob->friends( $alice );

  $alice2 = Storable::dclone( $alice );
 
  # $bob was cloned, too, thanks to the reference
  die if $alice2->has_friend( $bob );
 
  # get alice2's friend
  ($bob2) = $alice2->friends();
 
  # preserved relationship between bob2 and alice2
  die unless $bob2->has_friend( $alice );

{Class::InsideOut} also supports custom freeze and thaw hooks.  When an
object is frozen, if its class or any superclass provides
{STORABLE_freeze_hook} functions, they are each called with the object as an
argument ~prior~ to the rest of the freezing process.  This allows for
custom preparation for freezing, such as writing a cache to disk, closing
network connections, or disconnecting database handles.

Likewise, when a serialized object is thawed, if its class or any
superclass provides {STORABLE_thaw_hook} functions, they are each called
~after~ the object has been thawed with the thawed object as an argument.

User feedback on serialization needs and limitations is welcome.

== Thread-safety

Because {Class::InsideOut} uses memory addresses as indices to object
properties, special handling is necessary for use with threads.  When a new
thread is created, the Perl interpreter is cloned, and all objects in the new
thread will have new memory addresses.  Starting with Perl 5.8, if a {CLONE}
function exists in a package, it will be called when a thread is created to
provide custom responses to thread cloning.  (See [perlmod] for details.)

{Class::InsideOut} itself has a {CLONE} function that automatically fixes up
properties in a new thread to reflect the new memory addresses for all classes
created with {Class::InsideOut}.  {register} must be called on all newly
constructed inside-out objects to register them for use in
{Class::InsideOut::CLONE}.

Users are strongly encouraged not to define their own {CLONE} functions as
they may interfere with the operation of {Class::InsideOut::CLONE} and leave
objects in an undefined state.  Future versions may support a user-defined
CLONE hook, depending on demand.

=== Limitations
{fork} on Perl for Win32 is emulated using threads since Perl 5.6. (See
[perlfork].)  As Perl 5.6 did not support {CLONE}, inside-out objects that use 
memory addresses (e.g. {Class::InsideOut}) are not fork-safe for Win32 on
Perl 5.6.  Win32 Perl 5.8 {fork} is supported.

The technique for thread-safety requires creating weak references using
{Scalar::Util::weaken()}, which is implemented in XS.  If the XS-version of
[Scalar::Util] is not installed, {Class::InsideOut} will issue a warning
and continue without thread-safety.

= FUNCTIONS

== {id}

 $name{ id $object } = "Larry";

This is a shorter, mnemonic alias for {Scalar::Util::refaddr}.  It returns the
memory address of an object (just like {refaddr}) as the index to access
the properties of an inside-out object.

== {options}

 Class::InsideOut::options( \%new_options );
 %current_options = Class::InsideOut::options();

The {options} function sets default options for use with all subsquent
{property} calls for the calling package.  If called without arguments, this
function will return the options currently in effect.  When called with a hash
reference of options, these will be joined with the existing defaults,
overriding any options of the same name.

Valid options include:

* {privacy => 'public|private'}

 property rank => my %rank, { privacy => 'public' };

If the ~privacy~ option is equal to ~public~, an accessor will be created
with the same name as the label.  If the accessor is passed an argument, the
property will be set to the argument.  The accessor always returns the value of
the property.

* {set_hook => \&code_ref}

 public age => my %age, {
    set_hook => sub { /^\d+$/ or die "must be an integer" }
 };

Defines an accessor hook for when values are set. The hook subroutine receives
the entire argument list.  {$_} is locally aliased to the first argument for
convenience.  The property receives the value of {$_}. See [/"Accessor Hooks"]
for details.

* {get_hook => \&code_ref}

 public list => my %list, {
     get_hook => sub { @$_ }
 };

Defines an accessor hook for when values are retrieved.  {$_} is locally
aliased to the property value for the object.  ~The return value of the hook is
passed through as the return value of the accessor.~ See [/"Accessor Hooks"]
for details.

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
of options that will be applied to the property.  Valid options are the same
as listed for the {options} function and will override any
default options that have been set.

== {public}

 public height => my %height;
 public age => my %age, { %options };

This is an alias to {property} that also sets the privacy option to 'public'.
It will override default options or options passed as an argument.

== {register}

 register( bless $object, $class );

Registers an object for thread-safety.  This should be called as part of a
constructor on a object blessed into the current package.  Returns the
object (without modification).

= SEE ALSO

== Other modules on CPAN

* [Object::InsideOut] -- This is perhaps the most full-featured, robust
implementation of inside-out objects currently on CPAN.  It is highly
recommended if a more full-featured inside-out object builder is needed.
Its array-based mode is faster than hash-based implementations, but foreign
inheritance is handled via delegation, which imposes certain limitations.

* [Class::Std] -- Despite the name, this does not reflect best practices for
inside-out objects.  Does not provide thread-safety with CLONE, is not mod_perl
safe and doesn't support foreign inheritance.

* [Class::BuildMethods] -- Generates accessors with encapsulated storage using a
flyweight inside-out variant. Lexicals properties are hidden; accessors must be
used everywhere. Not thread-safe.

* [Lexical::Attributes] -- The original inside-out implementation, but missing
some key features like thread-safety.  Also, uses source filters to provide
Perl-6-like object syntax. Not thread-safe.

* [Class::MakeMethods::Templates::InsideOut] -- Not a very robust
implementation. Not thread-safe.  Not overloading-safe.  Has a steep learning
curve for the Class::MakeMethods system.

* [Object::LocalVars] -- My own original thought experiment with 'outside-in'
objects and local variable aliasing. Not safe for any production use and offers
very weak encapsulation.

== References

Much of the Perl community discussion of inside-out objects has taken place on
Perlmonks ([http://perlmonks.org]).  My scratchpad there has a fairly
comprehensive list of articles
([http://perlmonks.org/index.pl?node_id=360998]).  Some of the more
informative articles include:

* Abigail-II. "Re: Where/When is OO useful?". July 1, 2002.
[http://perlmonks.org/index.pl?node_id=178518]
* Abigail-II. "Re: Tutorial: Introduction to Object-Oriented Programming".
December 11, 2002. [http://perlmonks.org/index.pl?node_id=219131]
* demerphq. "Yet Another Perl Object Model (Inside Out Objects)". December 14,
2002. [http://perlmonks.org/index.pl?node_id=219924]
* xdg. "Threads and fork and CLONE, oh my!". August 11, 2005.
[http://perlmonks.org/index.pl?node_id=483162]
* jdhedden. "Anti-inside-out-object-ism". December 9, 2005.
[http://perlmonks.org/index.pl?node_id=515650]

= BUGS

Please report bugs or feature requests using the CPAN Request Tracker.
Bugs can be sent by email to {bug-Class-InsideOut@rt.cpan.org} or
submitted using the web interface at
[http://rt.cpan.org/Public/Dist/Display.html?Name=Class-InsideOut]

When submitting a bug or request, please include a test-file or a patch to an
existing test-file that illustrates the bug or desired feature.

= AUTHOR

David A. Golden (DAGOLDEN)

dagolden@cpan.org

http://dagolden.com/

= COPYRIGHT AND LICENSE

Copyright (c) 2006 by David A. Golden

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

