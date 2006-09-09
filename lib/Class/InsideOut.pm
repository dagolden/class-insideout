package Class::InsideOut;

$VERSION     = "0.02";
@ISA         = qw ( Exporter );
@EXPORT      = qw ( CLONE DESTROY );
@EXPORT_OK   = qw ( property register );
%EXPORT_TAGS = ( );
    
use strict;
use Carp;
use Exporter;
use Scalar::Util qw( refaddr weaken );

my %PROPERTIES_OF;
my %REGISTRY_OF;

sub import {
    my $package = shift;
    unshift @_, $package, @Class::InsideOut::EXPORT;
    goto &Exporter::import;
}
    
sub property(\%) {
    push @{ $PROPERTIES_OF{ scalar caller } }, $_[0];
    return;
}

sub register {
    my $obj = shift;
    weaken( $REGISTRY_OF{ scalar caller }{ refaddr $obj } = $obj );
    return $obj;
}

sub CLONE {
    my $class = shift;
    my $registry = $REGISTRY_OF{ $class };
    my $properties = $PROPERTIES_OF{ $class };
    
    for my $old_id ( keys %$registry ) {  
       
        # look under old_id to find the new, cloned reference
        my $object = $registry->{ $old_id };
        my $new_id = refaddr $object;

        # relocate data for all properties
        for my $prop ( @$properties ) {
            $prop->{ $new_id } = $prop->{ $old_id };
            delete $prop->{ $old_id };
        }

        # update the weak reference to the new, cloned object
        weaken ( $registry->{ $new_id } = $object );
        delete $registry->{ $old_id };
    }
   
    return;
}

sub DESTROY {
    my $obj = shift;
    my $class = ref $obj;
    my $obj_id = refaddr $obj;
    delete $_->{ $obj_id } for @{ $PROPERTIES_OF{ $class } };
    delete $REGISTRY_OF{ $class }{ $obj_id };
    return;
}

#--------------------------------------------------------------------------#
# private functions for use in testing
#--------------------------------------------------------------------------#
    
sub _object_count {
    my $class = shift;
    my $registry = $REGISTRY_OF{ $class };
    return defined $registry ? scalar( keys %$registry ) : 0;
}

sub _property_count {
    my $class = shift;
    my $properties = $PROPERTIES_OF{ $class };
    return defined $properties ? scalar @$properties : 0;
}

sub _leaking_memory {
    my $class = shift;
    my $obj_count = keys %{ $REGISTRY_OF{ $class } };
    my $properties = $PROPERTIES_OF{ $class };
    return scalar grep { $obj_count != scalar keys %$_ } @$properties;
}

1; #this line is important and will help the module return a true value
__END__

=head1 NAME

Class::InsideOut - a safe, simple inside-out object construction kit

=head1 SYNOPSIS

 package My::Class;
 
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

=head1 DESCRIPTION

This is an alpha release for a work in progress. It is a functional but
incomplete implementation of a simple, safe and streamlined toolkit for
building inside-out objects.  Unlike most other inside-out object building
modules already on CPAN, this module aims for minimalism and robustness.  It
uses no source filters, no attributes, supports foreign inheritance, does not
leak memory, is overloading-safe, is thread-safe for Perl 5.8 or better and
should be mod_perl compatible.

In its current state, it provides the minimal support necessary for safe
inside-out objects.  All other implementation details, including writing a
constructor and accessors, are left to the user.  Future versions will add
basic accessor support and serialization support.

=head2 Inside-out object basics

To be written.

=head1 USAGE

=head2 Importing C<Class::InsideOut>

To be written.

=head2 Declaring and accessing object properties

To be written.

=head2 Object destruction

To be written.

=head2 Foreign inheritance

To be written.

=head2 Serialization

To be written.

=head2 Thread-safety

To be written.

=head1 FUNCTIONS

=head2 C<property>

  property my %name;

Declares an inside-out property.  The argument must be a lexical hash, though
the C<my> keyword can be included as part of the argument rather than as a
separate statement.  No accessor is created, but the property will be tracked
for memory cleanup during object destruction and for proper thread-safety.

=head2 C<register>

  register $object;

Registers an object for thread-safety.  This should be called as part of a
constructor on a object blessed into the current package.  Returns the
object (without modification).

=head2 C<CLONE>

C<CLONE> is automatically exported to provide thread-safety to modules using
C<Class::InsideOut>.  See L<perlmod> for details.  It will be called
automatically by Perl if threads are in use and a new interpreter thread is
created.  It should never be called directly.

=head2 C<DESTROY>

This destructor is automatically exported to modules using C<Class::InsideOut>
to clean up object property memory usage during object destruction.  It should
never be called directly.  In the future, it will be enhanced to support a user
supplied C<DEMOLISH> method for additional, custom destruction actions.

=head1 SEE ALSO

=over

=item *

L<Object::InsideOut> -- Currently the most full-featured, robust implementation
of inside-out objects, but foreign inheritance is handled via delegation.
Highly recommended if a more full-featured inside-out object builder is
needed.

=item *

L<Class::Std> -- Despite the name, does not reflect best practices for
inside-out objects.  Does not provide thread-safety with CLONE, is not mod_perl
safe and doesn't support foreign inheritance.

=item *

L<Class::BuildMethods> -- Generates accessors with encapsulated storage using a
flyweight inside-out variant. Lexicals properties are hidden; accessors must be
used everywhere.

=item *

L<Lexical::Attributes> -- The original inside-out implementation, but missing
some key features like thread-safety.  Also, uses source filters to provide
Perl-6-like object syntax.

=item *

L<Class::MakeMethods::Templates::InsideOut> -- Not a very robust
implementation. Not thread-safe.  Not overloading-safe.  Has a steep learning
curve for the Class::MakeMethods system.

=item *

L<Object::LocalVars> -- My own original thought experiment with 'outside-in'
objects and local variable aliasing. Not production-safe and offers very weak
encapsulation.

=back

=head1 BUGS

Please report bugs using the CPAN Request Tracker at 
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-InsideOut>

When submitting a bug or request, please include a test-file or a patch to an
existing test-file that illustrates the bug or desired feature.

=head1 AUTHOR

David A. Golden (DAGOLDEN)

dagolden@cpan.org

http://dagolden.com/

=head1 COPYRIGHT

Copyright (c) 2006 by David A. Golden

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=cut
