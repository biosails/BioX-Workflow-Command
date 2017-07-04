package BioX::Workflow::Command::run::Rules::Directives::Types::HPC;

use Moose::Role;

has 'HPC' => (
    is      => 'rw',
    isa     => 'HashRef|ArrayRef',
    default => sub { {} }
);

1;
