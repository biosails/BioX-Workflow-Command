package BioX::Workflow::Command::run::Utils::Rules;

use MooseX::App::Role;
use Storable qw(dclone);
use Data::Merger qw(merger);
use Data::Walk;
use Data::Dumper;
use File::Path qw(make_path remove_tree);

with 'BioX::Workflow::Command::Utils::Files::TrackChanges';

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

has [ 'select_effect', 'omit_effect' ] => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
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

    $self->post_process_rules;

    $self->fh->close();
}

=head3 filter_rule_keys

First option is to use --use_timestamps
The user can also override the timestamps with --select_* --omit_*

Use the --select_rules and --omit_rules options to choose rules.

By default all rules are selected

=cut

sub filter_rule_keys {
    my $self = shift;

    if ( !$self->use_timestamps ) {
        $self->select_rule_keys( dclone( $self->rule_names ) );
    }
    $self->set_rule_keys('select');
    $self->set_rule_keys('omit');

    $self->app_log->info( 'Selected rules:' . "\t"
          . join( ', ', @{ $self->select_rule_keys } )
          . "\n" )
      unless $self->use_timestamps;
    $self->app_log->info( 'Using timestamps ... ' . 'Rules to process TBA' )
      if $self->use_timestamps;
}

=head3 set_rule_names

Iterate over the rule names and add them to our array

=cut

sub set_rule_names {
    my $self  = shift;
    my $rules = $self->workflow_data->{rules};

    my @rule_names = map { my ($key) = keys %{$_}; $key } @{$rules};
    $self->rule_names( \@rule_names );
    $self->app_log->info( 'Found rules:' . "\t" . join( ', ', @rule_names ) );
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

    my $effect = $cond . '_effect';

    my ( $has_rules, $has_bf, $has_af, $has_btw, $has_match ) =
      map { 'has_' . $cond . '_' . $_ }
      ( 'rules', 'before', 'after', 'between', 'match' );

    my ( $bf, $af ) = ( $cond . '_before', $cond . '_after' );

    my ( $btw, $all_rules, $all_matches ) =
      map { 'all_' . $cond . '_' . $_ } ( 'between', 'rules', 'match' );

    my ($rule_keys) = ( $cond . '_rule_keys' );

    if ( $self->$has_rules ) {
        $self->$effect(1);
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
        $self->$effect(1);
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
        $self->$effect(1);
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
        $self->$effect(1);
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
        $self->$effect(1);
        foreach my $match_rule ( $self->$all_matches ) {
            my @t_rules = $self->grep_rule_names( sub { /$match_rule/ } );
            map { push( @rules, $_ ) } @t_rules;
        }
    }

    $self->$rule_keys( \@rules ) if @rules;

    # return ( $rule_exists, @rule_name_exists );
}

=head3 check_select

See if the the current rule_name exists in either select_* or omit_*

=cut

sub check_select {
    my $self = shift;
    my $cond = shift || 'select';

    my $findex = 'first_index_' . $cond . '_rule_keys';
    my $index = $self->$findex( sub { $_ eq $self->rule_name } );

    return 0 if $index == -1;
    return 1;
}

=head3 process_rule

This function is just a placeholder for the other functions we need to process a rule

1. Do a sanity check of the rule - it could be yaml/json friendly but not biox friendly
2. Clone the local attr
3. Check for carrying indir/outdir INPUT/OUTPUT
4. Apply the local attr - Add all the local: keys to our attr
5. Get the keys of the rule
6. Finally, process the template, or the process: key

=cut

sub process_rule {
    my $self = shift;

    $self->sanity_check_rule;

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

    $self->app_log->info("");
    $self->app_log->info("Beginning sanity check");
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
        'Rule: ' . $self->rule_name . ' passes sanity check' );
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

    my @text = ();

    #TODO we should not just spit this out as it compare_mtimes
    #Instead save it as an object
    #And process the object at the end to account for --auto_deps

    $self->local_attr->{_modified} = 0;
    $self->process_obj->{ $self->rule_name } = {};

    foreach my $sample ( $self->all_samples ) {

        $self->app_log->info(
            'Processing Rule: ' . $self->rule_name . ' Sample: ' . $sample );
        $self->local_attr->sample($sample);
        $self->sample($sample);
        my $text = $self->eval_process();
        my $log  = $self->write_file_log();
        $text .= $log;
        push( @text, $text ) if $self->print_within_rule;

    }
    $self->process_obj->{ $self->rule_name }->{text} = \@text;

    $self->process_obj->{ $self->rule_name }->{meta} =
      $self->write_rule_meta('before_meta');

    return unless $self->use_timestamps;
    if ( $self->local_attr->{_modified} ) {
        $self->app_log->info(
            'One or more files were modified or are not logged for this rule');
    }
    else {
        $self->app_log->info('Zero files were modified for this rule');
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
    $attr->sample( $self->sample ) if $self->has_sample;

    my $process = $self->local_rule->{ $self->rule_name }->{process};
    my $text    = $attr->interpol_directive($process);
    $text = clean_text($text);

    $self->walk_FILES($attr);
    $self->clear_files;

    return $text;
}

sub clean_text {
    my $text     = shift;
    my @text     = split( "\n", $text );
    my @new_text = ();

    foreach my $t (@text) {
        $t =~ s/^\s+|\s+$//g;
        if ( $t !~ /^\s*$/ ) {
            push( @new_text, $t );
        }
    }

    $text = join( "\n", @new_text );
    return $text;
}

=head3 print_rule

Decide if we print the rule

There are 3 main decision trees

1. User specifies --select_*
2. User specified --omit_*
3. User specified --use_timestamps

select_* and omit_* take precedence over use_timestamps

=cut

sub print_rule {
    my $self       = shift;
    my $print_rule = 1;

    my $select_index = $self->check_select('select');
    my $omit_index   = $self->check_select('omit');

    if ( $self->use_timestamps && !$self->select_effect && !$self->omit_effect )
    {
        $self->app_log->info(
'Use timestamps in effect. Files have been modified or not logged by biox-workflow.'
        );
    }

    if ( !$select_index ) {
        $self->app_log->info(
            'Select rules in place. Skipping rule ' . $self->rule_name );
        $print_rule = 0;
    }

    if ($omit_index) {
        $self->app_log->info(
            'Omit rules in place. Skipping rule ' . $self->rule_name );
        $print_rule = 0;
    }

    $self->app_log->info( 'Processing rule ' . $self->rule_name . "\n" )
      if $print_rule;

    return $print_rule;
}

sub print_within_rule {
    my $self = shift;

    my $select_index = $self->check_select('select');

    if ( $self->use_timestamps ) {

        my $print_rule = 0;
        $print_rule = 1 if $self->local_attr->{_modified};
        if ( !$select_index && $print_rule ) {
            $self->add_select_rule_key( $self->rule_name );
        }
        return $print_rule;
    }
    return 1;
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
