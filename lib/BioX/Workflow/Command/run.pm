package BioX::Workflow::Command::run;

use v5.10;
use MooseX::App::Command;

use File::Path qw(make_path remove_tree);
use Cwd qw(abs_path getcwd);
use Data::Dumper;
use File::Basename;
use Try::Tiny;

use BioX::Workflow::Command::Utils::Traits qw(ArrayRefOfStrs);
use MooseX::Types::Path::Tiny qw/Path Paths AbsPath AbsFile/;
use BioX::Workflow::Command::run::Utils::Directives;

with 'BioX::Workflow::Command::run::Utils::Samples';
with 'BioX::Workflow::Command::run::Utils::Attributes';
with 'BioX::Workflow::Command::run::Utils::Rules';
with 'BioX::Workflow::Command::run::Utils::WriteMeta';
with 'BioX::Workflow::Command::Utils::Log';

command_short_description 'Run your workflow';
command_long_description
  'Run your workflow, process the variables, and create all your directories.';

=head1 BioX::Workflow::Command::run

This is the main class of the `biox-workflow.pl run` command.

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

option 'outfile' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self     = shift;
        my $workflow = $self->workflow;
        my @files    = fileparse( $self->workflow, qr/\.[^.]*/ );
        my $dt       = DateTime->now(time_zone => 'local');
        return
            $files[0] . '_'
          . $dt->ymd . '_'
          . $dt->time('-') . '.sh';
    },
    documentation => 'Write your workflow to a file',
);

option 'stdout' => (
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => 'Write workflows to STDOUT',
    predicate     => 'has_stdout',
);

has 'fh' => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $fh   = new IO::File;
        if ( $self->stdout ) {
            $fh->fdopen( fileno(STDOUT), "w" );
        }
        else {
            $fh->open( "> " . $self->outfile );
        }
        return $fh;
    },
);

# TODO move these to rules

option 'select_rules' => (
    traits        => ['Array'],
    is            => 'rw',
    required      => 0,
    isa           => ArrayRefOfStrs,
    documentation => 'Select rules to process',
    default       => sub { [] },
    cmd_split     => qr/,/,
    handles       => {
        all_select_rules  => 'elements',
        has_select_rules  => 'count',
        join_select_rules => 'join',
    },
    cmd_aliases => ['sr'],
);

option 'select_after' => (
    is            => 'rw',
    isa           => 'Str',
    required      => 0,
    predicate     => 'has_select_after',
    clearer       => 'clear_select_after',
    documentation => 'Select rules after and including a particular rule.',
    cmd_aliases   => ['sa'],
);

option 'select_before' => (
    is            => 'rw',
    isa           => 'Str',
    required      => 0,
    predicate     => 'has_select_before',
    clearer       => 'clear_select_before',
    documentation => 'Select rules before and including a particular rule.',
    cmd_aliases   => ['sb'],
);

option 'select_between' => (
    traits        => ['Array'],
    is            => 'rw',
    isa           => ArrayRefOfStrs,
    documentation => 'select rules to process',
    cmd_split     => qr/,/,
    required      => 0,
    default       => sub { [] },
    documentation => 'Select sets of rules. Ex: rule1-rule2,rule4-rule5',
    cmd_aliases   => ['sbtwn'],
    handles       => {
        all_select_between  => 'elements',
        has_select_between  => 'count',
        join_select_between => 'join',
    },
);

option 'omit_rules' => (
    traits        => ['Array'],
    is            => 'rw',
    required      => 0,
    isa           => ArrayRefOfStrs,
    documentation => 'Omit rules to process',
    default       => sub { [] },
    cmd_split     => qr/,/,
    handles       => {
        all_omit_rules  => 'elements',
        has_omit_rules  => 'count',
        join_omit_rules => 'join',
    },
    cmd_aliases => ['or'],
);

option 'omit_after' => (
    is            => 'rw',
    isa           => 'Str',
    required      => 0,
    predicate     => 'has_omit_after',
    clearer       => 'clear_omit_after',
    documentation => 'Omit rules after and including a particular rule.',
    cmd_aliases   => ['oa'],
);

option 'omit_before' => (
    is            => 'rw',
    isa           => 'Str',
    required      => 0,
    predicate     => 'has_omit_before',
    clearer       => 'clear_omit_before',
    documentation => 'Omit rules before and including a particular rule.',
    cmd_aliases   => ['ob'],
);

option 'omit_between' => (
    traits        => ['Array'],
    is            => 'rw',
    isa           => ArrayRefOfStrs,
    documentation => 'omit rules to process',
    cmd_split     => qr/,/,
    required      => 0,
    default       => sub { [] },
    documentation => 'Omit sets of rules. Ex: rule1-rule2,rule4-rule5',
    cmd_aliases   => ['obtwn'],
    handles       => {
        all_omit_between  => 'elements',
        has_omit_between  => 'count',
        join_omit_between => 'join',
    },
);

option 'select_match' => (
    traits        => ['Array'],
    is            => 'rw',
    required      => 0,
    isa           => ArrayRefOfStrs,
    documentation => 'Match rules to select',
    default       => sub { [] },
    cmd_split     => qr/,/,
    handles       => {
        all_select_match  => 'elements',
        has_select_match  => 'count',
        join_select_match => 'join',
    },
    cmd_aliases => ['sm'],
);

option 'omit_match' => (
    traits        => ['Array'],
    is            => 'rw',
    required      => 0,
    isa           => ArrayRefOfStrs,
    documentation => 'Match rules to omit',
    default       => sub { [] },
    cmd_split     => qr/,/,
    handles       => {
        all_omit_match  => 'elements',
        has_omit_match  => 'count',
        join_omit_match => 'join',
    },
    cmd_aliases => ['om'],
);

=head2 Attributes

=cut

=head2 Subroutines

=cut

sub BUILD {
    my $self = shift;

    # TO do add in configs and plugins
}

sub execute {
    my $self = shift;

    $self->print_opts;
    if(! $self->load_yaml_workflow){
      $self->app_log->warn('Exiting now.');
      return;
    }
    $self->apply_global_attributes;
    $self->get_global_keys;
    $self->get_samples;

    $self->write_workflow_meta('start');

    $self->iterate_rules;
}

sub load_yaml_workflow {
    my $self = shift;

    my $cfg;
    my @files = ( $self->workflow );
    my $valid = 1;

    $self->app_log->info( 'Loading workflow ' . $self->workflow . ' ...' );

    try {
        $cfg = Config::Any->load_files( { files => \@files, use_ext => 1 } );
    }
    catch {
        $self->app_log->warn(
            "Unable to load your workflow. The following error was received.\n"
        );
        $self->app_log->warn("$_\n");
        $valid = 0;
    };

    $self->app_log->info('Your workflow is valid') if $valid;

    #TODO Add Layering
    for (@$cfg) {
        my ( $filename, $config ) = %$_;
        $self->workflow_data($config);
    }

    if ( !exists $self->workflow_data->{global} ) {
        $self->workflow_data->{global} = [];
    }

    return $valid;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
