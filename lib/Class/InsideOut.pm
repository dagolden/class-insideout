package Class::InsideOut;

$VERSION     = "0.01";
@ISA         = qw (Exporter);
@EXPORT      = qw ( CLONE DESTROY );
@EXPORT_OK   = qw ();
%EXPORT_TAGS = ( );
    
use strict;
#use warnings; # not for Perl < 5.6
use Carp;
use Exporter;
use Scalar::Util qw( refaddr weaken );

my %PROPERTIES_OF;
my %REGISTRY_OF;

sub CLONE {
}

sub DESTROY {
    my $obj = shift;
    delete $REGISTRY_OF{ ref $obj }{ refaddr $obj };
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

#--------------------------------------------------------------------------#
# main pod documentation 
#--------------------------------------------------------------------------#

# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Class::InsideOut - placeholder for future implementation

=head1 SYNOPSIS

 use Class::InsideOut;

=head1 DESCRIPTION

This is a placeholder for a coming implementation of a streamlined, simple 
toolkit for building inside-out objects.  Unlike most other kits out there,
this module will aim towards minimalism.

In the meantime, I recommend L<Object::InsideOut> as the most robust current
alternative.

=cut


1; #this line is important and will help the module return a true value
__END__

#=head1 BUGS
#
#Please report bugs using the CPAN Request Tracker at L<http://rt.cpan.org/>

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
