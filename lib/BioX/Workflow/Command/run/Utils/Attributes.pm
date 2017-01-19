package BioX::Workflow::Command::run::Utils::Attributes;

# use Moose::Role;
use MooseX::App::Role;
use BioX::Workflow::Command::Utils::Traits qw(ArrayRefOfStrs);

has 'workflow_data' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { return {} },
);

=head3 local_rule

=cut

has 'local_rule' => (
    is     => 'rw',
    isa    => 'HashRef'
);

has 'global_attr' => (
    is       => 'rw',
    isa      => 'BioX::Workflow::Command::run::Utils::Directives',
    required => 0,
);

has 'local_attr' => (
    is       => 'rw',
    isa      => 'BioX::Workflow::Command::run::Utils::Directives',
    required => 0,
);

option 'samples' => (
    traits        => ['Array'],
    is            => 'rw',
    required      => 0,
    isa           => ArrayRefOfStrs,
    documentation => 'Choose a subset of samples',
    default       => sub { [] },
    cmd_split     => qr/,/,
    handles       => {
        all_samples  => 'elements',
        has_samples  => 'count',
        join_samples => 'join',
    },
    cmd_aliases => ['s'],
);

1;
