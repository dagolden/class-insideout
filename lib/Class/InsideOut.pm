package Class::InsideOut;

$VERSION     = "0.02";
@ISA         = qw (Exporter);
@EXPORT      = qw ( CLONE DESTROY );
@EXPORT_OK   = qw ( );
%EXPORT_TAGS = ( );
    
use strict;
#use warnings; # not for Perl < 5.6
use Carp;
use Exporter;
use Scalar::Util qw( refaddr weaken );

my %PROPERTIES_OF;
my %REGISTRY_OF;

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

sub property(\%) {
    push @{$PROPERTIES_OF{ scalar caller }}, $_[0];
    return;
}

sub register {
    my $obj = shift;
    weaken( $REGISTRY_OF{ scalar caller }{ refaddr $obj } = $obj );
    return $obj;
}
    
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
 
 use Class::InsideOut qw( id property register );

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
     # use 'id' to access properties for an object
     $name{ id $self } = shift;
     return $self;
   }
   return $name{ id $self };
 }
 
 sub greeting {
   my $self = shift;
   print "Hello, my name is " . $name { id $self } . "\n";
 }

=head1 DESCRIPTION

This is a placeholder for a coming implementation of a streamlined, simple 
toolkit for building inside-out objects.  Unlike most other kits out there,
this module will aim towards minimalism.

In the meantime, I recommend L<Object::InsideOut> as the most robust current
alternative.

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
