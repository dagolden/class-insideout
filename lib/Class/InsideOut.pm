package Class::InsideOut;

$VERSION     = "0.08";
@ISA         = qw ( Exporter );
@EXPORT      = qw ( );
@EXPORT_OK   = qw ( property register id );
%EXPORT_TAGS = ( );

use strict;
use Carp;
use Exporter;
use Scalar::Util qw( refaddr reftype weaken );
use Class::ISA;

my %PROPERTIES_OF;   # class => [ list of properties ]
my %PROPNAMES_OF;    # class => [ matching list of names ]
my %OBJECT_REGISTRY; # refaddr => object reference
my %CLASS_ISA;       # class => [ list of self and @ISA tree ]

BEGIN { *id = \&Scalar::Util::refaddr; }

sub import {
    my $caller = caller;
    {
        no strict 'refs';
        *{ $caller . "::DESTROY" } = _gen_DESTROY( $caller );
        *{ $caller . "::STORABLE_freeze" } = _gen_STORABLE_freeze( $caller );
        *{ $caller . "::STORABLE_thaw" } = _gen_STORABLE_thaw( $caller );
    }
    goto &Exporter::import;
}

sub property($\%) {
    push @{ $PROPNAMES_OF{ scalar caller } }, $_[0];
    push @{ $PROPERTIES_OF{ scalar caller } }, $_[1];
    return;
}

sub register {
    my $obj = shift;
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
    my @properties = map { @$_ } values %PROPERTIES_OF;

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

sub _gen_DESTROY {
    my $class = shift;
    return sub {
        my $obj = shift;
        my $obj_id = refaddr $obj; # cache for later property deletes

        # Call a custom DEMOLISH hook if one exists.
        my $demolish;
        {
            no strict 'refs';
            $demolish = *{ $class . "::DEMOLISH" }{CODE};
        }
        $demolish->($obj) if defined $demolish;

        # Clean up properties in all Class::InsideOut parents
        $CLASS_ISA{ $class } ||= [ Class::ISA::self_and_super_path( $class ) ];

        for my $c ( @{ $CLASS_ISA{ $class } } ) {
            next unless exists $PROPERTIES_OF{ $c };
            delete $_->{ $obj_id } for @{ $PROPERTIES_OF{ $c } };
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

        # extract properties to save
        my %property_vals;
        $CLASS_ISA{ $class } ||= [ Class::ISA::self_and_super_path( $class ) ];
        for my $c ( @{ $CLASS_ISA{ $class } } ) {
            next unless exists $PROPERTIES_OF{ $c };
            my $properties = $PROPERTIES_OF{ $c };
            for my $prop ( @$properties ) {
                my $value = exists $prop->{ refaddr $obj }
                          ? $prop->{ refaddr $obj }
                          : undef ;
                push @{ $property_vals{$c} }, $value;
            }
        }

        # extract object reference contents (by type)
        my $contents;
        my $type = reftype $obj;
        if    ( $type eq 'SCALAR' ) { $contents = \do{ my $s = $$obj } }
        elsif ( $type eq 'ARRAY'  ) { $contents = [ @$obj ]            }
        elsif ( $type eq 'HASH'   ) { $contents = { %$obj }            }

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

        # restore contents
        my $contents = $data->{contents};
        my $type = reftype $obj;
        if    ( $type eq 'SCALAR' ) { $$obj = $$contents }
        elsif ( $type eq 'ARRAY'  ) { @$obj = @$contents }
        elsif ( $type eq 'HASH'   ) { %$obj = %$contents }

        # restore properties
        $CLASS_ISA{ $class } ||= [ Class::ISA::self_and_super_path( $class ) ];
        for my $c ( @{ $CLASS_ISA{ $class } } ) {
            my $properties = $PROPERTIES_OF{ $c };
            my @property_vals = @{ $data->{properties}{ $c } };
            for my $prop ( @$properties ) {
                $prop->{ refaddr $obj } = shift @property_vals;
            }
        }

        return;
    };
}

#--------------------------------------------------------------------------#
# private functions for use in testing
#--------------------------------------------------------------------------#

sub _object_count {
    return scalar( keys %OBJECT_REGISTRY );
}

sub _property_count {
    my $class = shift;
    my $properties = $PROPERTIES_OF{ $class };
    return defined $properties ? scalar @$properties : 0;
}

sub _leaking_memory {
    my %leaks;

    for my $class ( keys %PROPERTIES_OF ) {
        for my $prop ( @{ $PROPERTIES_OF{ $class } } ) {
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

=head1 NAME

Class::InsideOut - a safe, simple inside-out object construction kit

=head1 SYNOPSIS

 package My::Class;
 
 use Class::InsideOut qw( property register id );
 use Scalar::Util qw( refaddr );
 
 # declare a lexical property "name" as a lexical ("my") hash
 property name => my %name;
 
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

=head1 LIMITATIONS AND ROADMAP

This is an B<alpha release> for a work in progress. It is B<functional but
incomplete> and should not be used for any production purpose.  It has been
released to solicit peer review and feedback.

WARNING: Version 0.08 introduces a B<BACKWARDS INCOMPATIBLE> syntax change to
the C<property> method.  C<property> now requires two arguments, including a
label for the property.  This label will be used in future versions to better
support introspection and accessor creation.

Serialization with L<Storable> appears to be working but may have unanticipated
bugs and could use some real-world testing.  Property destruction support for
various inheritance patterns (e.g.  diamond) is B<experimental> and the API may
change.  There is minimal argument checking or other error handling.  A future
version will also add very basic accessor support.

=head1 DESCRIPTION

This is a simple, safe and streamlined toolkit for building inside-out objects.
Unlike most other inside-out object building modules already on CPAN, this
module aims for minimalism and robustness.  It does not require derived classes
to subclass it; uses no source filters, attributes or CHECK blocks; supports
any underlying object type including foreign inheritance; does not leak memory;
is overloading-safe; is thread-safe for Perl 5.8 or better; and should be
mod_perl compatible.

It provides the minimal support necessary for creating safe inside-out objects.
All other implementation details, including writing a constructor and managing
inheritance, are left to the user.

Programmers seeking a more full-featured approach to inside-out objects are
encouraged to explore L<Object::InsideOut>.  Other implementations are briefly
noted in the L</"See Also"> section.

=head2 Inside-out object basics

Inside-out objects use the blessed reference as an index into lexical data
structures holding object properties, rather than using the blessed reference
itself as a data structure.

  $self->{ name }        = "Larry"; # classic, hash-based object
  $name{ refaddr $self } = "Larry"; # inside-out

The inside-out approach offers three major benefits:

=over

=item *

Enforced encapsulation: object properties cannot be accessed directly
from ouside the lexical scope that declared them

=item *

Making the property name part of a lexical variable rather than a hash-key
means that typos in the name will be caught as compile-time errors

=item *

If the memory address of the blessed reference is used as the index,
the reference can be of any type

=back

In exchange for these benefits, however, robust implementation of inside-out
objects can be quite complex.  C<Class::InsideOut> manages that complexity.

=head2 Philosophy of C<Class::InsideOut>

C<Class::InsideOut> provides a minimalist set of tools for building
safe inside-out classes with maximum flexibility.

It aims to offer minimal restrictions beyond those necessary for robustness of
the inside-out technique.  All capabilities necessary for robustness should be
automatic.  Anything that can be optional should be.  The design should not
introduce new restrictions unrelated to inside-out objects (such as attributes
and C<CHECK> blocks that cause problems for C<mod_perl> or the use of source
filters for a new syntax).

As a result, only a few things are mandatory:

=over

=item *

Properties must be based on hashes and declared via C<property>

=item *

Property hashes must be keyed on the C<Scalar::Util::refaddr> of the object
(or the optional C<id> alias to C<Scalar::Util::refaddr>).

=item *

C<register> must be called on all new objects

=back

All other implementation details, including constructors, initializers and
class inheritance management are left to the user.  This does requires some
additional work, but maximizes freedom.  C<Class::InsideOut> is intended to
be a base class providing only fundamental features.  Subclasses of
C<Class::InsideOut> could be written that build upon it to provide particular
styles of constructor, destructor and inheritance support.

=head1 USAGE

=head2 Importing C<Class::InsideOut>

  use Class::InsideOut;

By default, C<Class::InsideOut> imports three critical methods into the
namespace that uses it: C<DESTROY>, C<STORABLE_freeze> and C<STORABLE_thaw>.
These methods are intimately tied to correct functioning of the inside-out
objects. No other functions are imported by default.  Additional functions can
be imported by including them as arguments with C<use>:

  use Class::InsideOut qw( register property id );

Note that C<DESTROY> and C<STORABLE_*> will still be imported even without an
explicit request.  This can only be avoided by explicitly doing no importing,
via C<require> or passing an empty list to C<use>:

  use Class::InsideOut ();

There is almost no circumstance under which this is a good idea.  Users
seeking custom destruction behavior should consult L</"Object destruction"> and
the description of the C<DEMOLISH> method.

=head2 Declaring and accessing object properties

Object properties are declared with the C<property> function, which must
be passed a label and a lexical (i.e. C<my>) hash.

  property name => my %name;
  property age => my %age;

If users do not wish to import C<property>, properties may be declared
using a fully qualified syntax:

  Class::InsideOut::property name => my %name;

Properties are private by default and no accessors are created.  Users are
free to create accessors of any style.

Properties for an object are accessed through an index into the lexical hash
based on the memory address of the object.  This memory address I<must> be
obtained via C<Scalar::Util::refaddr>.  The alias C<id> is available for
brevity.

  $name{ refaddr $self } = "James";
  $age { id      $self } = 32;

In the future, additional options will be supported to create accessors
in various styles.

=head2 Object construction

C<Class::InsideOut> provides no constructor function as there are many possible
ways of constructing an inside-out object.  Additionally, this avoids
constraining users to any particular object initialization or superclass
initialization approach.

By using the memory address of the object as the index for properties, I<any>
type of reference can be used as the basis for an inside-out object with
C<Class::InsideOut>.

 sub new {
   my $class = shift;
 
   my $self = \do{ my $scalar };  # anonymous scalar
 # my $self = {};                 # anonymous hash
 # my $self = [];                 # anonymous array
 # open my $self, "<", $filename; # filehandle reference
 
   register( bless $self, $class );
 }

However, to ensure that the inside-out objects are thread-safe, the C<register>
function I<must> be called on the newly created object.  See L</register> for
details.

A more advanced technique uses another object, usually a superclass object,
as the object reference.  See L</"Foreign inheritance"> for details.

=head2 Object destruction

C<Class::InsideOut> automatically exports a customized C<DESTROY> function.
This function cleans up object property memory for all declared properties the
class and for all C<Class::InsideOut> based classes in the C<@ISA> array to
avoid memory leaks or data collision.

Additionally, if a user-supplied C<DEMOLISH> function is available in the same
package, it will be called with the object being destroyed as its argument.
C<DEMOLISH> can be used for custom destruction behavior such as updating class
properties, closing sockets or closing database connections.  Object properties
will not be deleted until after C<DEMOLISH> returns.

 # Sample DEMOLISH: Count objects demolished (for whatever reason)
 
 my $objects_destroyed;
 
 sub DEMOLISH {
   $objects_destroyed++;
 }

C<DEMOLISH> will only be automatically called if it exists for an object's
class.  C<DEMOLISH> will not be inherited and C<DEMOLISH> will not be called
automatically for any superclasses.

C<DEMOLISH> should manage any necessary calls to superclass C<DEMOLISH>
methods.  As with C<new>, implementation details are left to the user based on
the user's approach to object inheritance.  Depending on how the inheritance
chain is constructed and how C<DEMOLISH> is being used, users may wish to
entirely override superclass C<DEMOLISH> methods, rely upon C<SUPER::DEMOLISH>,
or may prefer to walk the entire C<@ISA> tree:

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
C<DEMOLISH> method.

=head2 Foreign inheritance

Because inside-out objects built with C<Class::InsideOut> can use any type of
reference for the object, inside-out objects can be built using other objects.
This is of greatest utility when extending a superclass object, without regard
for whether the superclass object is implemented with a hash or array or other
reference.

 use base 'IO::File';
 
 sub new {
   my ($class, $filename) = @_;
 
   my $self = IO::File->new( $filename );
 
   register( bless $self, $class );
 }

In the example above, C<IO::File> is a superclass.  The object is an
C<IO::File> object, re-blessed into the inside-out class.  The resulting
object can be used directly anywhere an C<IO::File> object would be,
without interfering with any of its own inside-out functionality.

Classes using foreign inheritance should provide a C<DEMOLISH> function that
calls the foreign class destructor explicitly.

=head2 Serialization

C<Class::InsideOut> has B<experimental> support for serialization with
L<Storable> by providing the C<STORABLE_freeze> and C<STORABLE_thaw> methods.
C<Storable> will use these methods to serialize.  They should not be called
directly.  Due to limitations of C<Storable>, this serialization will only work
for objects based on scalars, arrays or hashes.

References to object within the object being frozen will result in clones
upon thawing unless the other references are included in the same freeze
operation.  (See C<Storable> for details.)

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

User feedback on serialization needs and limitations is encouraged.

=head2 Thread-safety

Because C<Class::InsideOut> uses memory addresses as indices to object
properties, special handling is necessary for use with threads.  When a new
thread is created, the Perl interpreter is cloned, and all objects in the new
thread will have new memory addresses.  Starting with Perl 5.8, if a C<CLONE>
function exists in a package, it will be called when a thread is created to
provide custom responses to thread cloning.  (See L<perlmod> for details.)

C<Class::InsideOut> itself has a C<CLONE> function that automatically fixes up
properties in a new thread to reflect the new memory addresses for all classes
created with C<Class::InsideOut>.  C<register> must be called on all newly
constructed inside-out objects to register them for use in
C<Class::InsideOut::CLONE>.

Users are strongly encouraged not to define their own C<CLONE> functions as
they may interfere with the operation of C<Class::InsideOut::CLONE> and leave
objects in an undefined state.  Future versions may support a user-defined
CLONE hook, depending on demand.

Note: C<fork> on Perl for Win32 is emulated using threads since Perl 5.6. (See
L<perlfork>.)  As Perl 5.6 did not support C<CLONE>, inside-out objects using
memory addresses (e.g. C<Class::InsideOut> are not fork-safe for Win32 on 
Perl 5.6.  Win32 Perl 5.8 C<fork> is supported.

=head1 FUNCTIONS

=head2 C<property>

  property name => my %name;

Declares an inside-out property.  Two arguments are required.  The first is a
label for the property; in a future version, this label will be used for
introspection and generating accessors and thus should be a valid perl
identifier.  The second argument must be the lexical hash that will be used to
store data for that property.  Note that the C<my> keyword can be included as
part of the argument rather than as a separate statement.  No accessor is
created, but the property will be tracked for memory cleanup during object
destruction and for proper thread-safety.

=head2 C<register>

  register $object;

Registers an object for thread-safety.  This should be called as part of a
constructor on a object blessed into the current package.  Returns the
object (without modification).

=head2 C<id>

  $name{ id $object } = "Larry";

This is a shorter, mnemonic alias for C<Scalar::Util::refaddr>.  It returns the
memory address of an object (just like C<refaddr>) as the index to access
the properties of an inside-out object.

=head1 SEE ALSO

=head2 Other modules on CPAN

=over

=item *

L<Object::InsideOut> -- This is perhaps the most full-featured, robust
implementation of inside-out objects currently on CPAN.  It is highly
recommended if a more full-featured inside-out object builder is needed.
Its array-based mode is faster than hash-based implementations, but foreign
inheritance is handled via delegation, which imposes certain limitations.

=item *

L<Class::Std> -- Despite the name, this does not reflect best practices for
inside-out objects.  Does not provide thread-safety with CLONE, is not mod_perl
safe and doesn't support foreign inheritance.

=item *

L<Class::BuildMethods> -- Generates accessors with encapsulated storage using a
flyweight inside-out variant. Lexicals properties are hidden; accessors must be
used everywhere. Not thread-safe.

=item *

L<Lexical::Attributes> -- The original inside-out implementation, but missing
some key features like thread-safety.  Also, uses source filters to provide
Perl-6-like object syntax. Not thread-safe.

=item *

L<Class::MakeMethods::Templates::InsideOut> -- Not a very robust
implementation. Not thread-safe.  Not overloading-safe.  Has a steep learning
curve for the Class::MakeMethods system.

=item *

L<Object::LocalVars> -- My own original thought experiment with 'outside-in'
objects and local variable aliasing. Not safe for any production use and offers
very weak encapsulation.

=back

=head2 References

Much of the Perl community discussion of inside-out objects has taken place on
Perlmonks (L<http://perlmonks.org>).  My scratchpad there has a fairly
comprehensive list of articles
(L<http://perlmonks.org/index.pl?node_id=360998>).  Some of the more
informative articles include:

=over

=item *

Abigail-II. "Re: Where/When is OO useful?". July 1, 2002.
L<http://perlmonks.org/index.pl?node_id=178518>

=item *

Abigail-II. "Re: Tutorial: Introduction to Object-Oriented Programming".
December 11, 2002. L<http://perlmonks.org/index.pl?node_id=219131>

=item *

demerphq. "Yet Another Perl Object Model (Inside Out Objects)". December 14,
2002. L<http://perlmonks.org/index.pl?node_id=219924>

=item *

xdg. "Threads and fork and CLONE, oh my!". August 11, 2005.
L<http://perlmonks.org/index.pl?node_id=483162>

=item *

jdhedden. "Anti-inside-out-object-ism". December 9, 2005.
L<http://perlmonks.org/index.pl?node_id=515650>

=back

=head1 BUGS

Please report bugs or feature requests using the CPAN Request Tracker.
Bugs can be sent by email to C<bug-Class-InsideOut@rt.cpan.org> or
submitted using the web interface at
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-InsideOut>

When submitting a bug or request, please include a test-file or a patch to an
existing test-file that illustrates the bug or desired feature.

=head1 AUTHOR

David A. Golden (DAGOLDEN)

dagolden@cpan.org

http://dagolden.com/

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2006 by David A. Golden

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included with
this module.

=head1 DISCLAIMER OF WARRANTY

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

=cut
