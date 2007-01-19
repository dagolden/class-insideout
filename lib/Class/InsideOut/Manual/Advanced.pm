package Class::InsideOut::Manual::Advanced;
# Not really a .pm file, but holds wikidoc which will be
# turned into .pod by the Build.PL
$VERSION = "1.04";
use strict; # make CPANTS happy
1;
__END__

=begin wikidoc

= NAME

Class::InsideOut::Manual::Advanced - guide to advanced usage

= VERSION

This documentation refers to version %%VERSION%%

= DESCRIPTION

This manual provides further documentation for advanced usage of
Class::InsideOut.

== Customizing accessors

{Class::InsideOut} supports custom subroutine hooks to modify the behavior of
accessors.  Hooks are passed as property options: {set_hook} and {get_hook}.

The {set_hook} is called when the accessor is called with an argument.
The hook subroutine receives the entire argument list.  Just before the hook is
called, {$_} is locally aliased to the first argument for convenience.  When
the {set_hook} returns, the property is set equal to {$_}.  This feature is
useful for on-the-fly modification of the value that will be stored.

 public initials => my %initials, {
    set_hook => sub { $_ = uc $_ }
 };
 
 public tags => my %tags, {
    set_hook => sub { $_ = [ @_ ] } # stores arguments in a reference
 };

If the {set_hook} dies, the error is caught and rethrown with a preamble that
includes the name of the accessor.  The error should end with a newline to
prevent {die} from adding 'at ... filename line N'.  The correct
location will be added when the error is rethrown with {croak}:

 public height  => my %height, {
    set_hook => sub { /^\d+$/ or die "must be a positive integer" }
 };
 
 # dies with "height() must be a positive integer at ..."
 $person->height(3.5); 

~Note that the return value of the {set_hook} function is ignored.~  This
simplifies syntax in the case where {die} is used to validate input.

The {get_hook} is called when the accessor is called without an
argument.  Just before the hook is called, {$_} is set equal to the property
value of the object for convenience. The hook is called in the same context
(i.e. list versus scalar) as the accessor.  ~The return value of the hook is
passed through as the return value of the accessor.~  

 public tags => my %tags, {
    set_hook => sub { $_ = [ @_ ] }, # stores arguments in a reference
    get_hook => sub { @$_ }          # return property as a list
 };

Because {$_} is a copy, not an alias, of the property value, it
can be modified directly, if necessary, without affecting the underlying
property.

As with {set_hook}, the {get_hook} can die to indicate an error condition and
errors are handled similarly.  This could be used as a way to implement a
protected property:

 sub _protected { 
    die "is protected\n" unless caller(2)->isa(__PACKAGE__)
 }

 public hidden => my %hidden, {
    get_hook => \&_protected,
    set_hook => \&_protected,
 }

Accessor hooks can be set as a global default with the {options} function,
though they may still be overridden with options passed to specific properties.

== Black-box inheritance

Because inside-out objects built with {Class::InsideOut} can use any type of
reference for the object, inside-out objects can be built from other objects.
This is useful to extend a superclass without needing to know whether it is
based on hashes, array, or other types of blessed references.

 use base 'IO::File';
 
 sub new {
   my ($class, $filename) = @_;
 
   my $self = IO::File->new( $filename );
 
   register( $self, $class );
 }

In the example above, {IO::File} is a superclass.  The object is an
{IO::File} object, re-blessed into the inside-out class.  The resulting
object can be used directly anywhere an {IO::File} object would be,
without interfering with any of its own inside-out functionality.

Classes using black-box inheritance should consider providing a {DEMOLISH}
function that calls the black-box class destructor explicitly.

== Serialization

{Class::InsideOut} automatically imports {STORABLE_freeze} and {STORABLE_thaw}
methods to provide serialization support with [Storable].Due to limitations of
{Storable}, this serialization will only work for objects based on scalars,
arrays or hashes.

References to objects within the object being frozen will result in clones
upon thawing unless the other references are included in the same freeze
operation.  (See {Storable} for details.)

  # assume $alice and $bob are objects
  $alice->friends( $bob );
  $bob->friends( $alice );

  $alice2 = Storable::dclone( $alice );
 
  # $bob was cloned, too, thanks to the reference
  die if $alice2->has_friend( $bob ); # doesn't die
 
  # get alice2's friend
  ($bob2) = $alice2->friends();
 
  # preserved relationship between bob2 and alice2
  die unless $bob2->has_friend( $alice2 ); # doesn't die

{Class::InsideOut} also allows customizing freeze and thaw hooks.  When an
object is frozen, if its class or any superclass provides a
{FREEZE} method, they are each called with the object as an
argument ~prior~ to the rest of the freezing process.  This allows for
custom preparation for freezing, such as writing a cache to disk, closing
network connections, or disconnecting database handles.

Likewise, when a serialized object is thawed, if its class or any
superclass provides a {THAW} method, they are each called
~after~ the object has been thawed with the thawed object as an argument.

{Class::InsideOut} also supports serialization of singleton objects for
recent vesions of {Storable} that support {STORABLE_attach}.  Users must
signal that {STORABLE_attach} should be used instead of {STORABLE_thaw}
by adding {:singleton} to their import line as follows:

  use Class::InsideOut qw( :std :singleton );

When attaching, the singleton object will be recreated in one of two ways:

1. If the singleton class contains an {ATTACH} method, it will be called with
three arguments: the class name, a flag for whether this is part of a dclone,
and a data structure representing the object:

    $data = {
        class => ref $obj,              # class name
        type => $type,                  # object reference type
        contents => $contents,          # object reference contents
        properties => \%property_vals,  # HoH of classes and properties
    }

{contents} is a reference of the same type as {type}.  {properties} is a
multi-level hash, with the names of the class and any superclasses as top-level
keys and property labels as second-level keys.  This data may be used to
reconstruct or reattach to the singleton.  The {ATTACH} method should return
the singleton.

2. If no {ATTACH} routine is found, but the class has or inherits a {new}
method, then {new} will be called with no arguments and the result will be
returned as the singleton.

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

*Limitations:* 

{fork} on Perl for Win32 is emulated using threads since Perl
5.6. (See [perlfork].)  As Perl 5.6 did not support {CLONE}, inside-out objects
that use memory addresses (e.g. {Class::InsideOut}) are not fork-safe for Win32
on Perl 5.6.  Win32 Perl 5.8 {fork} is supported.

The technique for thread-safety requires creating weak references using
{Scalar::Util::weaken()}, which is implemented in XS.  If the XS-version of
[Scalar::Util] is not installed, {Class::InsideOut} will issue a warning
and continue without thread-safety.

= SEE ALSO

* [Class::InsideOut]
* [Class::InsideOut::Manual::About]

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

