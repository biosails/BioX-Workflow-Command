package BioX::Workflow::Command::run::Utils::Attributes;

use MooseX::App::Role;
use BioX::Workflow::Command::Utils::Traits qw(ArrayRefOfStrs);
use Storable qw(dclone);

=head1 Name

BioX::Workflow::Command::run::Utils::Attributes

=head2 Description

Attributes that are used for the duration of run

=cut

=head2 Command Line Options

=cut

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

=head2 Attributes

=cut

=head3 workflow_data

initial config file read into a perl structure

=cut

has 'workflow_data' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { return {} },
);

=head3 local_rule1

Rule we are currently evaluating

=cut

has 'local_rule' => (
    is         => 'rw',
    isa        => 'HashRef',
    lazy_build => 1,
);

=head3 global_attr

Attributes defined in the global key of the config

=cut

has 'global_attr' => (
    is       => 'rw',
    isa      => 'BioX::Workflow::Command::run::Utils::Directives',
    required => 0,
);

=head3 local_attr

Attributes in the local key of the rule

=cut

has 'local_attr' => (
    is       => 'rw',
    isa      => 'BioX::Workflow::Command::run::Utils::Directives',
    required => 0,
);

has 'p_local_attr' => (
    is       => 'rw',
    isa      => 'BioX::Workflow::Command::run::Utils::Directives',
    required => 0,
);

has 'rule_name' => (
    is         => 'rw',
    isa        => 'Str',
    lazy_build => 1,
);

has 'rule_names' => (
    traits        => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
    handles       => {
        all_rule_names  => 'elements',
        has_rule_names  => 'count',
        join_rule_names => 'join',
        first_index_rule_names => 'first_index',
        grep_rule_names => 'grep',
    },
);

has 'process_rule_names' => (
    traits        => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
    handles       => {
        all_process_rule_names  => 'elements',
        has_process_rule_names  => 'count',
        join_process_rule_names => 'join',
        first_index_process_rule_names => 'first_index',
    },
);

has 'p_rule_name' => (
    is         => 'rw',
    isa        => 'Str',
    lazy_build => 1,
);

sub apply_local_attr {
    my $self = shift;

    return unless exists $self->local_rule->{ $self->rule_name }->{local};

    $self->local_attr->create_attr(
        $self->local_rule->{ $self->rule_name }->{local} );
}

sub apply_global_attributes {
    my $self = shift;

    my $global_attr = BioX::Workflow::Command::run::Utils::Directives->new();
    $self->global_attr($global_attr);

    return unless exists $self->workflow_data->{global};

    $self->global_attr->create_attr( $self->workflow_data->{global} );
}

1;
