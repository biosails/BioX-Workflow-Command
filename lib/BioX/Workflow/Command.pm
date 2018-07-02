package BioX::Workflow::Command;

use v5.10;
our $VERSION = '2.4.1';

use MooseX::App 1.39 qw(Color);

app_strict 0;
app_exclude(
    'BioX::Workflow::Command::run::Rules',
    'BioX::Workflow::Command::run::Utils',
    'BioX::Workflow::Command::Utils',
    'BioX::Workflow::Command::inspect::Utils',
    'BioX::Workflow::Command::inspect::Exceptions',
    'BioX::Workflow::Command::Exceptions',
);

with 'BioX::Workflow::Command::Utils::Log';
with 'BioSAILs::Utils::Plugin';
with 'BioSAILs::Utils::LoadConfigs';

option '+config_base' => (
    is      => 'rw',
    default => '.biosailsworkflow',
);

sub BUILD { }

after 'BUILD' => sub {
    my $self = shift;

    return unless $self->plugins;

    $self->app_load_plugins( $self->plugins );
    $self->parse_plugin_opts( $self->plugins_opts );

    ##Must reload the configs to get any options from the plugins
    if ( $self->has_config_files ) {
        $self->load_configs;
    }
};

no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=encoding utf-8

=head1 NAME

BioX::Workflow::Command -  Scientific Workflow Creator

=head1 SYNOPSIS

  biosails render -w workflow.yml
  biosails -h

=head1 Documentation

See our website for the complete documentation. L<Documentation | https://biosails.abudhabi.nyu.edu/biosails/>

=head1 Available Workflows

Many workflows are available on the website. They can be downloaded as is, or modified using our in house workflow creator.

L<In house workflows | https://biosails.abudhabi.nyu.edu/biosails/index.php/templates/>

=head1 Quick Start

=head2 Get Help

  #Global Help
  biosails --help
  #Help Per Command
  biosails render --help

=head2 Run a Workflow

  biosails render -w workflow.yml #or --workflow

=head2 Create a new workflow

This creates a new workflow with rules rule1, rule2, rule3, with a few variables
to help get you started.

  biosails new -w workflow.yml --rules rule1,rule2,rule3

=head2 Add a new rule to a workflow

Add new rules to an existing workflow.

  biosails add -w workflow.yml --rules rule4

=head1 DESCRIPTION

BioX::Workflow::Command is a templating and rendering system for creating Scientific Workflows.

=head1 AUTHOR

Jillian Rowe E<lt>jillian.e.rowe@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2017- Jillian Rowe

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 Acknowledgements

As of version 0.03:

This modules continuing development is supported
by NYU Abu Dhabi in the Center for Genomics and
Systems Biology. With approval from NYUAD, this
information was generalized and put on github,
for which the authors would like to express their
gratitude.

Before version 0.03

This module was originally developed at and for Weill Cornell Medical
College in Qatar within ITS Advanced Computing Team. With approval from
WCMC-Q, this information was generalized and put on github, for which
the authors would like to express their gratitude.


=head1 SEE ALSO

L<Snakemake | https://snakemake.readthedocs.io/ >
L<BcBio | http://bcb.io/ >
L<Nextflow | https://www.nextflow.io/>
BioSAILs::Command
HPC::Runner::Command

=cut
