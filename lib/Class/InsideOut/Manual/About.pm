package Class::InsideOut::Manual::About;
# Not really a .pm file, but holds wikidoc which will be
# turned into .pod by the Build.PL
$VERSION = "1.03";
use strict; # make CPANTS happy
1;
__END__

=begin wikidoc

= NAME

Class::InsideOut::Manual::About - guide to this and other implementations of the
inside-out technique

= VERSION

This documentation refers to version %%VERSION%%

= DESCRIPTION

This manual provides an overview of the inside-out technique and its
application within {Class::InsideOut} and other modules.  It also provides a
list of references for further study.

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

In exchange for these benefits, robust implementation of inside-out
objects can be quite complex.  {Class::InsideOut} manages that complexity.

== Philosophy of {Class::InsideOut}

{Class::InsideOut} provides a set of tools for building safe inside-out classes
with maximum flexibility.

It aims to offer minimal restrictions beyond those necessary for robustness of
the inside-out technique.  All capabilities necessary for robustness should be
automatic.  Anything that can be optional should be.  The design should not
introduce new restrictions unrelated to inside-out objects, such as attributes
and {CHECK} blocks that cause problems for {mod_perl} or the use of source
filters for syntatic sugar.

As a result, only a few things are mandatory:

* Properties must be based on hashes and declared via {property}
* Property hashes must be keyed on the {Scalar::Util::refaddr}
* {register} must be called on all new objects

All other implementation details, including constructors, initializers and
class inheritance management are left to the user (though a very simple
constructor is available as a convenience).  This does requires some additional
work, but maximizes freedom.  {Class::InsideOut} is intended to be a base class
providing only fundamental features.  Subclasses of {Class::InsideOut} could be
written that build upon it to provide particular styles of constructor,
destructor and inheritance support.

== Other modules on CPAN

* [Object::InsideOut] -- This is perhaps the most full-featured, robust
implementation of inside-out objects currently on CPAN.  It is highly
recommended if a more full-featured inside-out object builder is needed.
Its array-based mode is faster than hash-based implementations, but black-box
inheritance is handled via delegation, which imposes certain limitations.

* [Class::Std] -- Despite the name, this does not reflect currently known best
practices for inside-out objects.  Does not provide thread-safety with CLONE
and doesn't support black-box inheritance.  Has a robust
inheritance/initialization system.

* [Class::BuildMethods] -- Generates accessors with encapsulated storage using
a flyweight inside-out variant. Lexicals properties are hidden; accessors must
be used everywhere. Not thread-safe.

* [Lexical::Attributes] -- The original inside-out implementation, but missing
some key features like thread-safety.  Also, uses source filters to provide
Perl-6-like object syntax. Not thread-safe.

* [Class::MakeMethods::Templates::InsideOut] -- Not a very robust
implementation. Not thread-safe.  Not overloading-safe.  Has a steep learning
curve for the Class::MakeMethods system.

* [Object::LocalVars] -- My own original thought experiment with 'outside-in'
objects and local variable aliasing. Not safe for any production use and offers
very weak encapsulation.

== References for further study

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

= SEE ALSO

* [Class::InsideOut]
* [Class::InsideOut::Manual::Advanced]

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

