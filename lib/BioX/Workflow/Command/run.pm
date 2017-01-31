package BioX::Workflow::Command::run;

use v5.10;
use MooseX::App::Command;

use File::Path qw(make_path remove_tree);
use Cwd qw(abs_path getcwd);
use Data::Dumper;
use List::Compare;
use YAML::XS 'LoadFile';
use Config::Any;
use Data::Dumper;
use Class::Load ':all';
use IO::File;
use Text::Template qw(fill_in_string);
use Storable qw(dclone);
use Log::Log4perl qw(:easy);

=head1 BioX::Workflow::Command::run

This is the main class of the `biox-workflow.pl run` command.

=cut

use BioX::Workflow::Command::Utils::Traits qw(ArrayRefOfStrs);
use MooseX::Types::Path::Tiny qw/Path Paths AbsPath AbsFile/;
use BioX::Workflow::Command::run::Utils::Directives;

with 'BioX::Workflow::Command::run::Utils::Samples';
with 'BioX::Workflow::Command::run::Utils::Attributes';
with 'BioX::Workflow::Command::run::Utils::Rules';

command_short_description 'Run your workflow';
command_long_description
  'Run your workflow, process the variables, and create all your directories.';

=head2 Command Line Options

=cut

option 'workflow' => (
    is            => 'rw',
    isa           => 'ArrayRef',
    required      => 1,
    documentation => 'Supply one or more workflows here.',
    cmd_split     => qr/,/,
    handles       => {
        all_workflow => 'elements',
    },
);

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

option 'match_rules' => (
    traits        => ['Array'],
    is            => 'rw',
    required      => 0,
    isa           => ArrayRefOfStrs,
    documentation => 'Match rules to process',
    default       => sub { [] },
    cmd_split     => qr/,/,
    handles       => {
        all_match_rules  => 'elements',
        has_match_rules  => 'count',
        join_match_rules => 'join',
    },
    cmd_aliases => ['mr'],
);

##Application log
has 'app_log' => (
    is      => 'rw',
    default => sub {
        my $self = shift;

        Log::Log4perl->init( \ <<'EOT');
  log4perl.category = DEBUG, Screen
  log4perl.appender.Screen = \
      Log::Log4perl::Appender::ScreenColoredLevels
  log4perl.appender.Screen.layout = \
      Log::Log4perl::Layout::PatternLayout
  log4perl.appender.Screen.layout.ConversionPattern = \
      [%d] %m %n
EOT
        return get_logger();
    }
);

=head2 Attributes

=cut

=head2 Subroutines

=cut

sub BUILD {
    my $self = shift;
    ##TODO add plugins here
}

sub execute {
    my $self = shift;

    $self->load_yaml_workflow;
    $self->apply_global_attributes;
    $self->get_samples;

    $self->iterate_rules;
}

sub load_yaml_workflow {
    my $self = shift;

    my $cfg =
      Config::Any->load_files( { files => $self->workflow, use_ext => 1 } );

    #TODO Add Layering
    for (@$cfg) {
        my ( $filename, $config ) = %$_;
        $self->workflow_data($config);
    }

    if ( !exists $self->workflow_data->{global} ) {
        $self->workflow_data->{global} = [];
    }

}

__PACKAGE__->meta->make_immutable;

1;
