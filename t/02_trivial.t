use Test::More;
use t::Util;

# work around win32 console buffering
Test::More->builder->failure_output(*STDOUT) 
    if ($^O eq 'MSWin32' && $ENV{HARNESS_VERBOSE});

plan tests => TC();

test_constructor("t::Object::Trivial");


