package t::Object::WithNew::Inherited;
use base 't::Object::WithNew';
use Class::InsideOut qw/ :std /;

private age => my %age;

sub reveal_age {
    return $age{ id shift };
}

1;
