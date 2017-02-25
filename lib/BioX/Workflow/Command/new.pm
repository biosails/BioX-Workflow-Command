package BioX::Workflow::Command::new;

use v5.10;
use MooseX::App::Command;

use Storable qw(dclone);
# use YAML::XS;
use YAML;

use MooseX::Types::Path::Tiny qw/Path/;

use BioX::Workflow::Command::Utils::Traits qw(ArrayRefOfStrs);

command_short_description 'Create a new workflow';
command_long_description 'Create a new workflow';

=head1 BioX::Workflow::Command::new

This is the main class of the `biox-workflow.pl new` command.

=cut

=head2 Command Line Options

=cut

#TODO This is so bad

option 'workflow' => (
    is            => 'rw',
    isa           => Path,
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
            $fh->open( "> " . $self->workflow );
        }
        return $fh;
    },
);

sub execute {
    my $self = shift;

    my $global = {
        global =>
            [
                { sample_rule      => "Sample_.*" },
                { indir            => 'data/raw' },
                { outdir           => 'data/processed' },
                { root_dir         => 'data' },
                { sample_bydir     => 1 },
                { by_sample_outdir => 1 },
            ]
    };

    my $rules = [];

    my @process = (
        'INDIR: {$self->indir}',
        'INPUT: {$self->INPUT}',
        'outdir: {$self->outdir} ',
        'OUTPUT: {$self->OUTPUT->[0]}',
    );
    my $pr = join( "\n", @process );

    my $rule_template = {
        'local' => [
            { INPUT  => '{$self->root_dir}/some_input_rule1' },
            { OUTPUT => ['some_output_rule1'] },
        ],
        process => $pr
    };

    foreach my $rule ( $self->all_rules ) {
        my $href = { $rule => dclone($rule_template) };
        push( @{$rules}, $href );
    }

    $global->{rules} = $rules;

    $self->fh->print(Dump($global));
    $self->fh->close;
}

1;
