use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Module::Build::JSAN::Installable',
    license             => 'perl',
    
    dist_author         => 'Nickolay Platonov <nplatonov@cpan.org>',
    dist_version_from   => 'lib/Module/Build/JSAN/Installable.pm',
    
    add_to_cleanup      => [ 'Module-Build-JSAN-Installable-*' ],
    create_makefile_pl  => 'passthrough',
    
    requires            => {
		'Module::Build'           => '0.35',
		'Module::Build::JSAN'     => '0.05',
		'Path::Class'             => '0.16',
		'JSON'                    => '2.00',
		'Text::Markdown'          => '1.0.26',
		'Text::MultiMarkdown'     => '1.0.29'
    },
    
    build_requires => {
        'Test::More'              => 0,
    },
    test_requires       => {
        'Capture::Tiny'           => 0.06
    }
    
);

$builder->create_build_script();
