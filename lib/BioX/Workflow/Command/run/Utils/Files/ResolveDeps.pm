package BioX::Workflow::Command::run::Utils::Files::ResolveDeps;

use MooseX::App::Role;
use String::Approx 'amatch';
use Algorithm::Dependency::Source::HoA;
use Algorithm::Dependency::Ordered;
use Try::Tiny;
use Data::Dumper;

# Not even close to this yet
option 'auto_deps' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
    documentation =>
      'Create a dependency tree using the INPUT/OUTPUTs of a rule',
);

has 'rule_deps' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
    handles => {
        seen_rule_deps_pairs => 'kv',
        clear_seen_rule_deps => 'clear',
    },
);

has 'graph' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
    handles => {
        seen_graph_pairs => 'kv',
        clear_seen_graph => 'clear',
    },
);

sub add_graph {
    my $self = shift;
    my $cond = shift;

    for my $pair ( $self->files_pairs ) {
        my $file = $pair->[0];
        if ( !exists $self->rule_deps->{ $self->rule_name }->{$cond}->{$file} )
        {
            $self->rule_deps->{ $self->rule_name }->{$cond}->{$file} = 1;
        }
    }
}

sub post_process_rules {
    my $self = shift;

    #Create flags for outputs that have a similar input
    $self->app_log->info();
    $self->app_log->info( 'Selected rules:' . "\t"
          . join( ', ', @{ $self->select_rule_keys } )
          . "\n" )
      if $self->use_timestamps;
    $self->app_log->info( 'Looking for orphan INPUTs '
          . '(INPUTs with no corresponding OUTPUTs)' );

    foreach my $rule ( $self->all_select_rule_keys ) {
        $self->check_input_output($rule);
    }

    $self->process_auto_deps;

    $self->print_process_workflow;
}

sub print_process_workflow {
    my $self = shift;

    foreach my $rule ( $self->all_rule_names ) {
        #TODO This should be named select_rule_names
        my $index = $self->first_index_select_rule_keys( sub { $_ eq $rule } );
        next if $index == -1;
        $self->app_log->info( 'Post processing ' . $rule );

        my $meta = $self->process_obj->{$rule}->{meta} || [];
        my $text = $self->process_obj->{$rule}->{text} || [];

        map { $self->fh->say($_) } @{$meta};
        map { $self->fh->say($_) } @{$text};

    }
}

=head3

Iterate over rule_names
If they are in select_rules use those also
Otherwise only use the schedule
If using timestamps we have a timestamp, but in no particular order
If select rules we have select_rules, but also in no particular Ordered
for $s @schedule { if print_rule (print the process_obj)}
We also need to update the #HPC meta to include deps

=cut

sub process_auto_deps {
    my $self = shift;

    return unless $self->auto_deps;

    foreach my $rule ( $self->select_rule_keys ) {


        $self->graph->{$rule} = [] if !exists $self->graph->{$rule};
        my $meta = $self->process_obj->{$rule}->{meta};
        $meta = [] unless $meta;
        my $before_meta = join( "\n", @{$meta} );

        if ( $before_meta =~ m/#HPC deps=/ ) {
            next;
        }
        my @deps = @{ $self->graph->{$rule} };
        if (@deps) {
            chomp($before_meta);
            $before_meta .= "\n#HPC deps=" . join( ',', @deps );
        }
        my @text = split( "\n", $before_meta );
        $self->process_obj->{$rule}->{meta} = \@text;
    }

}

#TODO Add in deps check

sub check_input_output {
    my $self = shift;
    my $rule = shift;

    #if this exists it means we already processed this through hpc-deps
    # return if exists $self->graph->{$rule};
    $self->graph->{$rule} = [] if !exists $self->graph->{$rule};

    my @INPUTS = keys %{ $self->rule_deps->{$rule}->{INPUT} };

    #TODO Add Seen

    foreach my $srule ( $self->all_select_rule_keys ) {
        next if $srule eq $rule;

        my @inter = grep( $self->rule_deps->{$srule}->{OUTPUT}->{$_}, @INPUTS );
        if ( !@inter ) {
            my @OUTPUTS = keys %{ $self->rule_deps->{$srule}->{OUTPUT} };
            map {
                my @matches = amatch( $_, @OUTPUTS );
                $self->app_log->warn( "Orphan INPUT:"
                      . "\tRule: $rule  File: $_\n"
                      . "\tPossible matches include "
                      . join( ", ", @matches ) )
                  if @matches
            } @INPUTS;
        }
        else {
            push( @{ $self->graph->{$rule} }, $srule );
        }
    }

}

1;