use strict;
use Module::Build;

my $class = Module::Build->subclass(
    class => "Module::Build::WikiDoc",
    code => <<'SUBCLASS', );

    sub ACTION_wikidoc {
        my $self = shift;
        eval "use Pod::WikiDoc";
        if ( $@ eq '' ) {
            my $parser = Pod::WikiDoc->new( 
                { comment_blocks => 1 } 
            );
            for my $src ( keys %{ $self->find_pm_files() } ) {
                (my $tgt = $src) =~ s{\.pm$}{.pod};
                $parser->filter( {
                    input   => $src,
                    output  => $tgt,
                });
                print "Creating $tgt\n";
                $tgt =~ s{\\}{/}g;
                $self->_add_to_manifest( 'MANIFEST', $tgt );
            }
        }
        else {
            warn "Pod::WikiDoc not available. Skipping wikidoc.\n";
        }
    }

    sub ACTION_test {
        my $self = shift;
        my $missing_pod;
        for my $src ( keys %{ $self->find_pm_files() } ) {
            (my $tgt = $src) =~ s{\.pm$}{.pod};
            $missing_pod = 1 if ! -e $tgt;
        }
        if ( $missing_pod ) {
            $self->depends_on('wikidoc');
            $self->depends_on('build');
        }
        $self->SUPER::ACTION_test;
    }

    sub ACTION_testpod {
        my $self = shift;
        $self->depends_on('wikidoc');
        $self->SUPER::ACTION_testpod;
    }

    sub ACTION_distdir {
        my $self = shift;
        $self->depends_on('wikidoc');
        $self->SUPER::ACTION_distdir;
    }

SUBCLASS

my $builder = $class->new( 
    module_name         => 'Class::InsideOut',
    dist_author         => 'David A. Golden <dagolden@cpan.org>',
    license             => 'perl',
    create_readme       => 0,
    create_makefile_pl  => 'traditional',
    requires        => {
        'perl'           => 5.005, # says Perl::MinimumVersion
        'base'           => 0,
        'Class::ISA'     => 0, # why reimplement what works
        'Config'         => 0,
        'Exporter'       => 0,
        'Test::More'     => 0.45, # thread-safe
        'Scalar::Util'   => 1.09, # refaddr
    },
    add_to_cleanup      => [ 'Class-InsideOut-*' ],
    meta_add            => { 
        no_index => { 
            file => [ qw{ 
                lib\Class\InsideOut\Manual\About.pm
                lib\Class\InsideOut\Manual\Advanced.pm 
            } ] 
        } 
    },

);

$builder->create_build_script;
