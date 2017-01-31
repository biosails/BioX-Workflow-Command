package BioX::Workflow::Command::run::Utils::Rules;

use MooseX::App::Role;
use Storable qw(dclone);
use Data::Merger qw(merger);
use Data::Walk;
use Data::Dumper;

=head1 Name

BioX::Workflow::Command::run::Utils::Rules

=head2 Description

Role for Rules

=cut

has 'rule_keys' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { return [] },
);

has 'local_rule_keys' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { return [] },
);

#This should be in its own role
sub iterate_rules {
    my $self = shift;

    my $rules = $self->workflow_data->{rules};

    $self->set_rule_names;

    foreach my $rule (@$rules) {

        $self->local_rule($rule);
        $self->process_rule;
        $self->p_rule_name( $self->rule_name );
        $self->p_local_attr( dclone( $self->local_attr ) );

    }
}

=head3 set_rule_names

Iterate over the rule names and add them to our array

=cut

sub set_rule_names {
    my $self  = shift;
    my $rules = $self->workflow_data->{rules};

    my @rule_names = map { my ($key) = keys %{$_}; $key } @{$rules};
    $self->rule_names( \@rule_names );
}

=head3 set_process_rules

If we have any select_* or match_rules, get those rules before we start processing

=cut

sub set_process_rules {
    my $self = shift;

    my @rules = ();

    if ( $self->has_select_rules ) {
        foreach my $r ( $self->all_select_rules ) {
            if ( $self->first_index_rule_names( sub { $_ eq $r } ) != -1 ) {
                push( @rules, $r );
            }
            else {
                $self->app_log->warn(
                    "You selected a rule $r that does not exist");
            }
        }
    }
    elsif ( $self->has_select_before ) {
        my $index =
          $self->first_index_rule_names( sub { $_ eq $self->select_before } );
        if ( $index == -1 ) {
            $self->app_log->warn( "You selected a rule "
                  . $self->select_before
                  . " that does not exist" );
        }
        for ( my $x = 0 ; $x <= $index ; $x++ ) {
            push( @rules, $self->rule_names->[$x] );
        }
    }
    elsif ( $self->has_select_after ) {
        my $index =
          $self->first_index_rule_names( sub { $_ eq $self->select_after } );
        if ( $index == -1 ) {
            $self->app_log->warn( "You selected a rule "
                  . $self->select_before
                  . " that does not exist" );
        }
        for ( my $x = $index ; $x < $self->has_rule_names; $x++ ) {
            push( @rules, $self->rule_names->[$x] );
        }
    }
    elsif ( $self->has_select_between ) {
        foreach my $rule ( $self->all_select_between ) {
            my (@array) = split( '-', $rule );
            my $index1  = $self->first_index_rule_names( sub { $_ eq $array[0] } );
            my $index2  = $self->first_index_rule_names( sub { $_ eq $array[1] } );
            for ( my $x = $index1 ; $x <= $index2 ; $x++ ) {
                push( @rules, $self->rule_names->[$x] );
            }
        }
    }
    elsif ( $self->match_rules ) {
      foreach my $match_rule ($self->all_match_rules){
        my @t_rules = $self->grep_rule_names( sub { /$match_rule/ } );
        map { push( @rules, $_ ) } @t_rules;
      }
    }
    else {
        $self->process_rule_names( dclone( $self->rule_names ) );
        return;
    }

    $self->process_rule_names( \@rules );
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

    $self->get_keys();
    $self->template_process;
}

=head3 sanity_check_rule

Check the rule to make sure it only has 1 key

=cut

#TODO make this into a type Instead

sub sanity_check_rule {
    my $self = shift;

    my @keys = keys %{ $self->local_rule };

    #TODO Add app log
    if ( $#keys != 0 ) {
        die print "You should only have one rule name!\n";
    }

    $self->rule_name( $keys[0] );

    warn "Your rule does not have a process!\n"
      unless exists $self->local_rule->{ $self->rule_name }->{process};

    if ( !exists $self->local_rule->{ $self->rule_name }->{local} ) {
        $self->local_rule->{ $self->rule_name }->{local} = [];
        return;
    }

    my $ref = $self->local_rule->{ $self->rule_name }->{local};

    die print 'Your variable declarations should begin with an array!'
      unless ref($ref) eq 'ARRAY';
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
        $self->local_attr->INPUT( dclone( $self->p_local_attr->OUTPUT ) );
    }

    $self->local_attr->stash( dclone( $self->p_local_attr->stash ) );
}

=head3 template_process

Do the actual processing of the rule->process

=cut

sub template_process {
    my $self = shift;

    foreach my $sample ( @{ $self->samples } ) {

        $self->local_attr->sample($sample);
        $self->template_process_sample;
    }
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

    my @special_keys = ( 'indir', 'outdir', 'INPUT', 'OUTPUT' );
    foreach my $key (@special_keys) {
        if ( !$seen{$key} ) {
            unshift( @local_keys, $key );
        }
    }

    map { push( @global_keys, $_ ) } @local_keys;

    $self->rule_keys( \@global_keys );
}

sub template_process_sample {
    my $self = shift;

    my $process = $self->local_rule->{ $self->rule_name }->{process};

    my $attr = dclone( $self->local_attr );
    $self->check_indir_outdir($attr);
    $attr->walk_process_data( $self->rule_keys );

    my $text = $attr->interpol_directive($process);

    return $text;
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

    #We should only do this if the dir is not specified

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
