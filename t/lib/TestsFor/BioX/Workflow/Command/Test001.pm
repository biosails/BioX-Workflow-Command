package TestsFor::BioX::Workflow::Command::Test001;

use Test::Class::Moose;
use Cwd;
use FindBin qw($Bin);
use File::Path qw(make_path remove_tree);
use Data::Dumper;
use Capture::Tiny ':all';
use BioX::Workflow::Command;
use YAML::XS;

sub test_001 : Tags(req) {
    require_ok('BioX::Workflow::Command');

    require_ok('BioX::Workflow::Command::run');
    require_ok('BioX::Workflow::Command::new');
    require_ok('BioX::Workflow::Command::add');

    require_ok('BioX::Workflow::Command::run::Utils::Attributes');
    require_ok('BioX::Workflow::Command::run::Rules::Directives');
    require_ok('BioX::Workflow::Command::run::Utils::Rules');
    require_ok('BioX::Workflow::Command::run::Utils::Samples');
    require_ok('BioX::Workflow::Command::run::Utils::WriteMeta');
    require_ok('BioX::Workflow::Command::run::Utils::Files::ResolveDeps');
    require_ok('BioX::Workflow::Command::run::Utils::Files::TrackChanges');

    require_ok('BioX::Workflow::Command::Utils::Create');
    require_ok('BioX::Workflow::Command::Utils::Files');
    require_ok('BioX::Workflow::Command::Utils::Log');
    require_ok('BioX::Workflow::Command::Utils::Plugin');
    require_ok('BioX::Workflow::Command::Utils::Traits');

    ##DEPRACATED
    require_ok('BioX::Workflow::Command::Utils::Files::TrackChanges');
}

1;
