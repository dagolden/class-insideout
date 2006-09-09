use Module::Build;
# See perldoc Module::Build for details of how this works

Module::Build->new( 
    module_name         => 'Class::InsideOut',
    dist_author         => 'David A. Golden <dagolden@cpan.org>',
    license             => 'perl',
    create_readme       => 1,
    create_makefile_pl  => 'traditional',
    requires        => {
        perl            => 5.005, # says Perl::MinimumVersion
        base            => 0,
        Class::ISA      => 0, # why reimplement what works
        Config          => 0,
        Exporter        => 0,
        Test::More      => 0.48,
        Scalar::Util    => 1.09,
    },
)->create_build_script;
