use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name       => 'XML-Chain',
    license           => 'perl',
    dist_author       => 'Jozef Kutej <jkutej@cpan.org>',
    dist_version_from => 'lib/XML/Chain.pm',
    configure_requires => {
        'Module::Build' => '0.36',
    },
    build_requires => {
        'Test::Most'  => 0,
        'File::Temp'  => 0,
        'Path::Class' => 0,
    },
    requires => {
        'perl'            => 5.010,
        'XML::LibXML'     => 2.0100,   # Added the unique_key() method to XML::LibXML::Node
        'XML::Tidy'       => 0,
        'IO::Any'         => 0,
        'Moose'           => 0,
        'MooseX::Aliases' => 0,
        'Moose::Exporter' => 0,
    },
    script_files => [qw()],
    add_to_cleanup => ['XML-Chain-*'],
    create_readme  => 1,
    meta_merge => {
        resources => {
            repository => 'https://github.com/meon/XML-Chain.git',
            bugtracker => 'https://github.com/meon/XML-Chain/issues',
        },
        keywords => [ qw/ XML chain build manipulation traversal LibXML / ],
    },
);

$builder->create_build_script();
