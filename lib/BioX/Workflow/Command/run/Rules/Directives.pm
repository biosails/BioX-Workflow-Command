package BioX::Workflow::Command::run::Rules::Directives;

use Moose;
use namespace::autoclean;
use Moose::Util qw/apply_all_roles/;

with 'BioX::Workflow::Command::run::Rules::Directives::Types::HPC';
with 'BioX::Workflow::Command::run::Rules::Directives::Types::Path';
with 'BioX::Workflow::Command::run::Rules::Directives::Types::List';
with 'BioX::Workflow::Command::run::Rules::Directives::Types::Stash';
with 'BioX::Workflow::Command::run::Rules::Directives::Types::Hash';
with 'BioX::Workflow::Command::run::Rules::Directives::Types::Array';
with 'BioX::Workflow::Command::run::Rules::Directives::Types::CSV';
with 'BioX::Workflow::Command::run::Rules::Directives::Types::Config';
with 'BioX::Workflow::Command::run::Rules::Directives::Interpolate';
with 'BioX::Workflow::Command::run::Rules::Directives::Sample';
with 'BioX::Workflow::Command::run::Rules::Directives::Walk';
with 'BioX::Workflow::Command::Utils::Log';

use Try::Tiny;

=head2 Other Directives

=cut

has 'register_types' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { return {} },
    handles => {
        'get_register_types' => 'get',
        'set_register_types' => 'set',
    },
);

has 'register_process_directives' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { return {} },
    handles => {
        'get_register_process_directives' => 'get',
        'set_register_process_directives' => 'set',
    },
);

##TODO add this so that we can have user defined types
has 'register_namespace' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
    handles => {
        'all_register_namespace'    => 'elements',
        'count_register_namespace'  => 'count',
        'has_register_namespace'    => 'count',
        'has_no_register_namespace' => 'is_empty',
    },
    trigger => sub {
        my $self = shift;
        foreach my $role ( $self->all_register_namespace ) {
            try {
                apply_all_roles( $self, $role );
            }
            catch {
                $self->app_log->warn(
                    'There was an error registering role ' . $role );
                $self->app_log->warn("$_\n");
            }
        }
    },
);

has 'override_process' => (
    traits    => ['Bool'],
    is        => 'rw',
    isa       => 'Bool',
    default   => 0,
    predicate => 'has_override_process',
    documentation =>
      q(Instead of for my $sample (@sample){ DO STUFF } just DOSTUFF),
    handles => {
        set_override_process   => 'set',
        clear_override_process => 'unset',
    },
);

##Add in support for chunks
##This is useful for features where we want to do things like
##split a file into parts
##count by kmers, etc

=head3 create_attr

Add attributes to $self-> namespace

=cut

sub create_attr {
    my $self = shift;
    my $data = shift;

    my $meta = __PACKAGE__->meta;

    $meta->make_mutable;
    my $seen = {};

    for my $attr ( $meta->get_all_attributes ) {
        next if $attr->name eq 'stash';
        $seen->{ $attr->name } = 1;
    }

    # Get workflow_data structure
    # Workflow is an array of hashes

    foreach my $href ( @{$data} ) {

        if ( !ref($href) eq 'HASH' ) {
            ##TODO add more informative structure options here
            ##TODO Add app_log
            warn 'Your variable declarations should be key/value!';
            return;
        }

        while ( my ( $k, $v ) = each( %{$href} ) ) {

            if ( !exists $seen->{$k} ) {

                if ( $k eq 'stash' ) {
                    $self->merge_stash($v);
                }
                elsif ( $self->can($k) ) {
                    ##Should this be next of just skip ?
                    next;
                }
                elsif ( $self->search_registered_types( $meta, $k, $v ) ) {

                    # next;
                }
                elsif ( ref($v) eq 'HASH' ) {
                    $self->create_HASH_attr( $meta, $k );
                }
                elsif ( ref($v) eq 'ARRAY' ) {
                    $self->create_ARRAY_attr( $meta, $k );
                }
                else {
                    $self->create_reg_attr( $meta, $k );
                }
            }

            try{
            $self->$k($v) if defined $v;
            }
            catch{
                $self->app_log->warn(
                    'There was an assiging key. ' . $k );
                $self->app_log->warn("$_\n");
            }
        }

    }

    $meta->make_immutable;
}

sub search_registered_types {
    my $self = shift;
    my $meta = shift;
    my $k    = shift;
    my $v    = shift;

    foreach my $key ( keys %{ $self->register_types } ) {
        next unless exists $self->register_types->{$key}->{lookup};
        next unless exists $self->register_types->{$key}->{builder};
        my $lookup_ref = $self->register_types->{$key}->{lookup};
        my $builder    = $self->register_types->{$key}->{builder};

        foreach my $lookup ( @{$lookup_ref} ) {
            if ( $k =~ m/$lookup/ ) {
                $self->$builder( $meta, $k, $v );
                return 1;
            }
        }
    }

    return 0;
}

sub create_reg_attr {
    my $self = shift;
    my $meta = shift;
    my $k    = shift;

    $meta->add_attribute(
        $k => (
            is         => 'rw',
            lazy_build => 1,
        )
    );
}

=head3 create_blank_attr

placeholder for some types

=cut

sub create_blank_attr {
    my $self = shift;
    my $meta = shift;
    my $k    = shift;

    $meta->add_attribute(
        $k => (
            is      => 'rw',
            default => '',
        )
    );
}

sub BUILD { }

after 'BUILD' => sub {
    my $self = shift;
    $self->interpol_directive_cache( {} );
};

no Moose;
__PACKAGE__->meta->make_immutable;

1;