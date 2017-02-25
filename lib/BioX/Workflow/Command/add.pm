package BioX::Workflow::Command::add;

use v5.10;
use MooseX::App::Command;

use Storable qw(dclone);
use YAML::XS;

use MooseX::Types::Path::Tiny qw/Path/;

use BioX::Workflow::Command::Utils::Traits qw(ArrayRefOfStrs);

command_short_description 'Add a rule to an existing workflow';
command_long_description 'Add a rule to an existing workflow';

=head1 BioX::Workflow::Command::add

This is the main class of the `biox-workflow.pl new` command.

=cut

=head2 Command Line Options

=cut

option 'workflow' => (
    is            => 'rw',
    isa           => AbsFile,
    required      => 1,
    coerce        => 1,
    documentation => 'Supply a workflow',
);

option 'rules' => (
    traits        => ['Array'],
    is            => 'rw',
    required      => 0,
    isa           => ArrayRefOfStrs,
    documentation => 'Add rules',
    default       => sub { ['rule1'] },
    cmd_split     => qr/,/,
    handles       => {
        all_rules  => 'elements',
        has_rules  => 'count',
        join_rules => 'join',
    },
    cmd_aliases => ['r'],
);



1;
