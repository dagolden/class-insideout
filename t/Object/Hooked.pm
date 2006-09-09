package t::Object::Hooked;

use Class::InsideOut ':std';

# $_ has the first argument in it for convenience
public integer => my %integer, { 
    set_hook => sub { /\A\d+\z/ or die "must be an integer" }, # long die
};

# first argument is also available directly
public word => my %word, {
    set_hook => sub { $_[0] =~ /\A\w+\z/ or die "must be a Perl word\n" },
};

# Changing $_ changes what gets stored
public uppercase => my %uppercase, {
    set_hook => sub { $_[0] = uc },
};

# Full @_ is available, but only first gets stored
public list => my %list, {
    set_hook => sub { $_ = ref $_ eq 'ARRAY' ? $_ : [ @_ ] },
    get_hook => sub { @$_ },
};

public reverser => my %reverser, {
    set_hook => sub { $_ = (ref $_ eq 'ARRAY') ? $_ : [ @_ ] },
    get_hook => sub {  reverse @$_ }
};

sub new {
    register( bless {}, shift );
}

1;
