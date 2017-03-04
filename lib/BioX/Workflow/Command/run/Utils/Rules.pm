package BioX::Workflow::Command::run::Utils::Rules;

use MooseX::App::Role;
use Storable qw(dclone);
use Data::Merger qw(merger);
use Data::Walk;
use Data::Dumper;
use File::Path qw(make_path remove_tree);

=head1 Name

BioX::Workflow::Command::run::Utils::Rules

=head2 Description

Role for Rules

=cut

# TODO Change this to rules?

has 'rule_keys' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { return [] },
);

has 'local_rule_keys' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { return [] },
    handles => {
        all_local_rule_keys => 'elements',
        has_local_rule_keys => 'count',
    },
);

has 'global_keys' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { return [] },
    handles => {
        all_global_keys => 'elements',
        has_global_keys => 'count',
    },
);

#This should be in its own role
sub iterate_rules {
    my $self = shift;

    $self->set_rule_names;
    my $rules = $self->workflow_data->{rules};

    $self->filter_rule_keys;

    foreach my $rule (@$rules) {

        $self->local_rule($rule);
        $self->process_rule;
        $self->p_rule_name( $self->rule_name );
        $self->p_local_attr( dclone( $self->local_attr ) );

    }

    $self->fh->close();
}

=head3 filter_rule_keys

Use the --select_rules and --omit_rules options to choose rules.

By default all rules are selected

=cut

sub filter_rule_keys {
    my $self = shift;

    $self->select_rule_keys( dclone( $self->rule_names ) );
    $self->set_rule_keys('select');
    $self->set_rule_keys('omit');

}

=head3 set_rule_names

Iterate over the rule names and add them to our array

=cut

sub set_rule_names {
    my $self  = shift;
    my $rules = $self->workflow_data->{rules};

    my @rule_names = map { my ($key) = keys %{$_}; $key } @{$rules};
    $self->rule_names( \@rule_names );
    $self->app_log->info( 'Found rules ' . join( ', ', @rule_names ) ."\n");
}

=head3 set_rule_keys

If we have any select_* or select_match, get those rules before we start processing

=cut

sub set_rule_keys {
    my $self = shift;
    my $cond = shift || 'select';

    my @rules            = ();
    my $rule_exists      = 1;
    my @rule_name_exists = ();

    my ( $has_rules, $has_bf, $has_af, $has_btw, $has_match ) =
      map { 'has_' . $cond . '_' . $_ }
      ( 'rules', 'before', 'after', 'between', 'match' );

    my ( $bf, $af ) = ( $cond . '_before', $cond . '_after' );

    my ( $btw, $all_rules, $all_matches ) =
      map { 'all_' . $cond . '_' . $_ } ( 'between', 'rules', 'match' );

    my ($rule_keys) = ( $cond . '_rule_keys' );

    if ( $self->$has_rules ) {
        foreach my $r ( $self->$all_rules ) {
            if ( $self->first_index_rule_names( sub { $_ eq $r } ) != -1 ) {
                push( @rules, $r );
            }
            else {
                $self->app_log->warn(
                    "You selected a rule $r that does not exist");
                $rule_exists = 0;
                push( @rule_name_exists, $r );
            }
        }
    }
    elsif ( $self->$has_bf ) {
        my $index = $self->first_index_rule_names( sub { $_ eq $self->$bf } );
        if ( $index == -1 ) {
            $self->app_log->warn( "You "
                  . $cond
                  . "ed a rule "
                  . $self->$bf
                  . " that does not exist" );
            $rule_exists = 0;
            push( @rule_name_exists, $self->$bf );
        }
        for ( my $x = 0 ; $x <= $index ; $x++ ) {
            push( @rules, $self->rule_names->[$x] );
        }
    }
    elsif ( $self->$has_af ) {
        my $index = $self->first_index_rule_names( sub { $_ eq $self->$af } );
        if ( $index == -1 ) {
            $self->app_log->warn( "You "
                  . $cond
                  . "ed a rule "
                  . $self->$af
                  . " that does not exist" );
            $rule_exists = 0;
            push( @rule_name_exists, $self->$af );
        }
        for ( my $x = $index ; $x < $self->has_rule_names ; $x++ ) {
            push( @rules, $self->rule_names->[$x] );
        }
    }
    elsif ( $self->$has_btw ) {
        foreach my $rule ( $self->$btw ) {
            my (@array) = split( '-', $rule );

            my $index1 =
              $self->first_index_rule_names( sub { $_ eq $array[0] } );
            my $index2 =
              $self->first_index_rule_names( sub { $_ eq $array[1] } );

            if ( $index1 == -1 || $index2 == -1 ) {
                $self->app_log->warn( "You "
                      . $cond
                      . "ed a set of rules "
                      . join( ',', $self->$btw )
                      . " that does not exist" );
                $rule_exists = 0;
                push( @rule_name_exists, $rule );
            }

            for ( my $x = $index1 ; $x <= $index2 ; $x++ ) {
                push( @rules, $self->rule_names->[$x] );
            }
        }
    }
    elsif ( $self->$has_match ) {
        foreach my $match_rule ( $self->$all_matches ) {
            my @t_rules = $self->grep_rule_names( sub { /$match_rule/ } );
            map { push( @rules, $_ ) } @t_rules;
        }
    }

    $self->$rule_keys( \@rules ) if @rules;
    return ( $rule_exists, @rule_name_exists );
}

=head3 process_rule

This function is just a placeholder for the other functions we need to process a rule

=cut

sub process_rule {
    my $self = shift;

    $self->sanity_check_rule;

    ##Initialize the local_attr
    $self->local_attr( dclone( $self->global_attr ) );

    $self->carry_directives;

    $self->apply_local_attr;

    $self->get_keys;
    $self->template_process;
}

=head3 sanity_check_rule

Check the rule to make sure it only has 1 key

=cut

#TODO make this into a type Instead

sub sanity_check_rule {
    my $self = shift;

    my @keys = keys %{ $self->local_rule };

    $self->app_log->info('Beginning sanity check for rule...');
    if ( $#keys != 0 ) {
        $self->app_log->fatal('You should only have one rule name!');
        $self->sanity_check_fail;
        return;
    }

    $self->rule_name( $keys[0] );
    $self->app_log->info( 'Sanity check on rule ' . $self->rule_name );

    if ( !exists $self->local_rule->{ $self->rule_name }->{process} ) {
        $self->app_log->fatal('Your rule does not have a process!');
        $self->sanity_check_fail;
        return;
    }

    if ( !exists $self->local_rule->{ $self->rule_name }->{local} ) {
        $self->local_rule->{ $self->rule_name }->{local} = [];
    }
    else {
        my $ref = $self->local_rule->{ $self->rule_name }->{local};

        if ( !ref($ref) eq 'ARRAY' ) {
            $self->app_log->fatal(
                'Your variable declarations should begin with an array!');
            $self->sanity_check_fail;
            return;
        }
    }

    $self->app_log->info(
        'Rule : ' . $self->rule_name . ' passes sanity check' );
}

sub sanity_check_fail {
    my $self = shift;

    my $rule_example = <<EOF;
global:
    - indir: data/raw
    - outdir: data/processed
    - file_rule: (sample.*)$
    - by_sample_outdir: 1
    - sample_bydir: 1
    - copy1:
        local:
            - indir: '{\$self->my_dir}'
            - INPUT: '{\$self->indir}/{\$sample}.csv'
            - HPC:
                - mem: '40GB'
                - walltime: '40GB'
        process: |
            echo 'MyDir on {\$self->my_dir}'
            echo 'Indir on {\$self->indir}'
            echo 'Outdir on {\$self->outdir}'
            echo 'INPUT on {\$self->INPUT}'
EOF
    $self->app_log->fatal('Skipping this rule.');
    $self->app_log->fatal(
'Here is an example workflow. For more information please see biox-workflow.pl new --help.'
    );
    $self->app_log->fatal($rule_example);
}

=head3 carry_directives

At the beginning of each rule the previous outdir should be the new indir, and the previous OUTPUT should be the new INPUT

Stash should be carried over

Outdir should be global_attr->outdir/rule_name

=cut

sub carry_directives {
    my $self = shift;

    $self->local_attr->outdir(
        $self->global_attr->outdir . '/' . $self->rule_name );

    return unless $self->has_p_rule_name;

    $self->local_attr->indir( dclone( $self->p_local_attr->outdir ) );

    if ( $self->p_local_attr->has_OUTPUT ) {
        if ( ref( $self->p_local_attr->OUTPUT ) ) {
            $self->local_attr->INPUT( dclone( $self->p_local_attr->OUTPUT ) );
        }
        else {
            $self->local_attr->INPUT( $self->p_local_attr->OUTPUT );
        }
    }

    $self->local_attr->stash( dclone( $self->p_local_attr->stash ) );
}

=head3 template_process

Do the actual processing of the rule->process

=cut

sub template_process {
    my $self = shift;

    my $print_rule = $self->print_rule;

    $self->write_rule_meta('before_meta') if $print_rule;

    foreach my $sample ( $self->all_samples ) {

        $self->local_attr->sample($sample);
        my $text = $self->eval_process($print_rule);
        $self->fh->say($text) if $print_rule;

    }
}

sub get_global_keys {
    my $self        = shift;
    my @global_keys = ();

    map { my ($key) = keys %{$_}; push( @global_keys, $key ) }
      @{ $self->workflow_data->{global} };

    $self->global_keys( \@global_keys );
}

sub get_keys {
    my $self = shift;

    my %seen = ();
    my @local_keys = map { my ($key) = keys %{$_}; $seen{$key} = 1; $key }
      @{ $self->local_rule->{ $self->rule_name }->{local} };

    my @global_keys = ();
    map { my ($key) = keys %{$_}; push( @global_keys, $key ) if !$seen{$key} }
      @{ $self->workflow_data->{global} };

    $self->local_rule_keys( dclone( \@local_keys ) );

    #This should be an object for extending
    my @special_keys = ( 'indir', 'outdir', 'INPUT', 'OUTPUT' );
    foreach my $key (@special_keys) {
        if ( !$seen{$key} ) {
            unshift( @local_keys, $key );
        }
    }

    map { push( @global_keys, $_ ) } @local_keys;

    $self->rule_keys( \@global_keys );
}

sub walk_attr {
    my $self = shift;

    my $attr = dclone( $self->local_attr );
    $self->check_indir_outdir($attr);
    $attr->walk_process_data( $self->rule_keys );

    if ( $attr->create_outdir ) {
        make_path( $attr->outdir );
    }

    return $attr;
}

sub eval_process {
    my $self = shift;

    my $attr = $self->walk_attr;

    my $process = $self->local_rule->{ $self->rule_name }->{process};
    my $text    = $attr->interpol_directive($process);

    return $text;
}

=head3 print_rule

Decide if we print the rule

=cut

sub print_rule {
    my $self       = shift;
    my $print_rule = 1;

    my $select_index =
      $self->first_index_select_rule_keys( sub { $_ eq $self->rule_name } );

    if ( $select_index == -1 ) {
        $self->app_log->info(
            'Select rules in place. Skipping rule ' . $self->rule_name );
        $print_rule = 0;
    }

    my $omit_index =
      $self->first_index_omit_rule_keys( sub { $_ eq $self->rule_name } );

    if ( $omit_index != -1 ) {
        $self->app_log->info(
            'Omit rules in place. Skipping rule ' . $self->rule_name );
        $print_rule = 0;
    }

    $self->app_log->info( 'Processing rule ' . $self->rule_name . "\n" )
      if $print_rule;

    return $print_rule;
}

=head3 check_indir_outdir

If by_sample_outdir we pop the last dirname, append {$sample} to the base dir, and then add back on the popped value

There are 2 cases we do not do this

1. The indir of the first rule
2. If the user specifies indir/outdir in the local vars

=cut

sub check_indir_outdir {
    my $self = shift;
    my $attr = shift;

    return unless $attr->by_sample_outdir;
    return unless $self->has_sample;
    return if $attr->override_process;

    # If indir/outdir is specified in the local config
    # then we don't evaluate it
    foreach my $dir ( ( 'indir', 'outdir' ) ) {
        if ( grep /$dir/, @{ $self->local_rule_keys } ) {
            next;
        }

        if ( $dir eq 'indir' && !$self->has_p_rule_name ) {
            my $new_dir = File::Spec->catdir( $attr->$dir, '{$sample}' );
            $attr->$dir($new_dir);
            next;
        }

        my @dirs = File::Spec->splitdir( $attr->$dir );
        my $last = '';
        if ($#dirs) {
            $last = pop(@dirs);
        }

        my $base_dir = File::Spec->catdir(@dirs);
        my $new_dir = File::Spec->catdir( $base_dir, '{$sample}', $last );
        $attr->$dir($new_dir);
    }

}

1;
