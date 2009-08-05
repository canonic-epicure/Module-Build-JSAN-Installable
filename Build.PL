use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Module::Build::JSAN::Installable',
    license             => 'perl',
    
    dist_author         => 'Nickolay Platonov <nplatonov@cpan.org>',
    dist_version_from   => 'lib/Module/Build/JSAN/Installable.pm',
    
    build_requires => {
        'Test::More' => 0,
    },
    
    add_to_cleanup      => [ 'Module-Build-JSAN-Installable-*' ],
    create_makefile_pl => 'passthrough',
    
    requires           => {
		'Module::Build::JSAN' => '0.05',
		'Path::Class' => '0.16',
		'JSON' => '2.00',
		'Text::Markdown' => '1.0.24'
    }
    
);

$builder->create_build_script();
