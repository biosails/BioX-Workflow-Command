package BioX::Workflow::Command::inspect;

use v5.10;
use MooseX::App::Command;
use namespace::autoclean;

use Data::Dumper;
use Storable qw(dclone);
use YAML;
use Try::Tiny;
use JSON;

extends 'BioX::Workflow::Command';
use BioSAILs::Utils::Traits qw(ArrayRefOfStrs);
use Capture::Tiny ':all';

with 'BioX::Workflow::Command::run::Rules::Directives::Walk';
with 'BioX::Workflow::Command::run::Utils::Samples';
with 'BioX::Workflow::Command::run::Utils::Attributes';
with 'BioX::Workflow::Command::run::Rules::Rules';
with 'BioX::Workflow::Command::run::Utils::WriteMeta';
with 'BioX::Workflow::Command::run::Utils::Files::TrackChanges';
with 'BioX::Workflow::Command::run::Utils::Files::ResolveDeps';
with 'BioX::Workflow::Command::Utils::Files';
with 'BioX::Workflow::Command::inspect::Utils::ParsePlainText';

use BioX::Workflow::Command::run;
use BioX::Workflow::Command::inspect::Exceptions::Path;

command_short_description 'Inspect your workflow';
command_long_description
'Inspect individual variables in your workflow. Syntax is global.var for global, or rule.rulename.var for rules. Use the --all flag to inspect all variables.';

=head1 BioX::Workflow::Command::inspect

  biox inspect -h
  biox inspect -w variant_calling.yml --path /rules/.*/local/indir

=cut

=head2 Attributes

=cut

option 'all' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

option 'path' => (
    is        => 'rw',
    isa       => 'Str',
    required  => 0,
    predicate => 'has_path',
);

option 'json' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has 'inspect_obj' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { return {} },
);

=head3 samples

This is our actual list of samples

=cut

=head2 Subroutines

=cut

sub execute {
    my $self = shift;

    if ( !$self->load_yaml_workflow ) {
        $self->app_log->warn('Exiting now.');
        return;
    }
    $self->get_line_declarations;

    $DB::single = 2;

    $self->apply_global_attributes;
    $self->global_attr->create_outdir(0);
    $self->return_global_as_object;

    $self->samples( ['Sample_XYZ'] );

    $self->set_rule_names;
    my $rules = $self->workflow_data->{rules};

    $self->filter_rule_keys;

    foreach my $rule (@$rules) {
        $self->local_rule($rule);
        $self->process_rule;
        $self->p_rule_name( $self->rule_name );
        $self->p_local_attr( dclone( $self->local_attr ) );
    }

    $self->check_for_json;
}

sub check_for_json {
    my $self = shift;
    ##TODO These should be too different interfaces
    if ( $self->json ) {
        $self->app_log->warn(
            'You have selected a path, but this is not applied with --json')
          if $self->has_path;
        my $json =
          JSON->new->utf8->pretty->allow_blessed->encode( $self->inspect_obj );
        print $json;
    }
    else {
        $self->find_inspect_obj;
        $self->comment_char('');
    }

}

sub find_inspect_obj {
    my $self = shift;

    if ( $self->has_path ) {
        my @split = split( '/', $self->path );
        if ( scalar @split >= 5 ) {
            my $except =
              BioX::Workflow::Command::inspect::Exceptions::Path->new(
                info => 'Your split path contains too many elements.'
                  . ' Portions may still work, but you are probably not getting what you expect.'
              );
            $except->warn( $self->app_log );
        }
        if ( $split[1] eq 'rules' ) {
            $self->find_inspect_obj_rules( \@split );
        }
        elsif ( $split[1] eq 'global' ) {
            $self->find_inspect_obj_global( \@split );
        }
        elsif ( $split[1] eq '*' ) {
            $self->find_inspect_obj_rules( \@split );
            $self->find_inspect_obj_global( \@split );
        }
        else {
            my $except =
              BioX::Workflow::Command::inspect::Exceptions::Path->new(
                info => 'You are searching for something that does not exist.'
                  . ' Please see the documentation for allowed values of dpath.'
              );
            $except->fatal( $self->app_log );
        }
    }
}

sub find_inspect_obj_rules {
    my $self  = shift;
    my $split = shift;

    foreach my $rule ( @{ $self->rule_names } ) {
        my $rule_name = $split->[2];
        if ( !$rule_name ) {
            my $except =
              BioX::Workflow::Command::inspect::Exceptions::Path->new(
                    info => 'You must supply a  rule name '
                  . $rule
                  . ' Examples: --path /rules/.*/local/.*,--path /rules/some_rule/local/.*, --path /rules/.*/process'
              );
            $except->fatal( $self->app_log );
            exit 1;
        }
        if ( $rule =~ m/$rule_name/ ) {
            print "Rule: $rule\n";
            my $wanted_key = $split->[4];
            if ( !$wanted_key ) {
                my $except =
                  BioX::Workflow::Command::inspect::Exceptions::Path->new(
                        info => 'You must supply a key to rule '
                      . $rule
                      . ' Examples: --path /rules/.*/local/.*, --path /rules/.*/process'
                  );
                $except->fatal( $self->app_log );
                exit 1;
            }
            elsif ( !$split->[3] ) {
                my $except =
                  BioX::Workflow::Command::inspect::Exceptions::Path->new(
                    info => 'You must supply a local/process and key to rule '
                      . $rule
                      . ' Examples: --path /rules/.*/local/.*, --path /rules/.*/process'
                  );
                $except->fatal( $self->app_log );
                exit 1;
            }
            elsif ( $split->[3] eq 'local' ) {
                $self->find_inspect_obj_rule_keys( $rule, $wanted_key );
            }
            elsif ( $split->[3] eq 'process' ) {
                $self->find_inspect_obj_rule_process($rule);
            }
            elsif ( $split->[3] eq '.*' ) {
                $self->find_inspect_obj_rule_keys( $rule, $wanted_key );
                $self->find_inspect_obj_rule_process($rule);
            }
        }
        print "\n\n";
    }
}

sub find_inspect_obj_rule_keys {
    my $self       = shift;
    my $rule       = shift;
    my $wanted_key = shift;
    my $seen       = 0;

    my @keys = keys %{ $self->inspect_obj->{rules}->{$rule}->{local} };
    foreach my $key (@keys) {
        $seen = 1;
        if ( $key =~ m/$wanted_key/ ) {
            my $value =
              $self->inspect_obj->{rules}->{$rule}->{local}->{$key};
            my $pp = $self->write_pretty_meta( $key, $value );
            print "Key:" . $pp . "\n";
        }
    }
    $self->app_log->warn( 'We were not able to find key ' . $wanted_key )
      unless $seen;
}

sub find_inspect_obj_rule_process {
    my $self = shift;
    my $rule = shift;

    my $texts = $self->process_obj->{$rule}->{text};
    print "\tProcess:\t" . $texts->[0] . "\n";
}

sub find_inspect_obj_global {
    my $self  = shift;
    my $split = shift;

    my $wanted_key = $split->[2];
    print "Global\n";
    my $seen = 0;

    my @keys = keys %{ $self->inspect_obj->{global} };
    foreach my $key (@keys) {
        if ( $key =~ m/$wanted_key/ ) {
            $seen = 1;
            my $value = $self->inspect_obj->{global}->{$key};
            my $pp = $self->write_pretty_meta( $key, $value );
        }
    }

    $self->app_log->warn( 'We were not able to find key ' . $wanted_key )
      unless $seen;
}

##Overrididng the eval_process
sub eval_process {
    my $self = shift;

    $self->sample('Sample_XYZ');
    my $attr = $self->walk_attr;

    $self->walk_indir_outdir($attr);

    my $text = $self->eval_rule($attr);
    $text = clean_text($text);

    $self->walk_FILES($attr);
    $self->clear_files;

    $self->local_attr->stash( dclone( $attr->stash ) );

    $self->return_rule_as_obj($attr);

    return $text;
}

sub return_rule_as_obj {
    my $self = shift;
    my $attr = shift;

    my $clean = {};
    foreach my $key ( @{ $self->rule_keys } ) {
        if ( ref( $attr->$key ) eq 'Path::Tiny' ) {
            $clean->{$key} = $attr->$key->stringify;
            next;
        }
        $clean->{$key} = $attr->$key;
    }

    my @haves = ( 'indir', 'outdir', 'INPUT', 'OUTPUT', 'stash' );
    foreach my $h (@haves) {
        if ( !exists $clean->{$h} ) {
            $clean->{$h} = $self->check_path( $attr->$h );
        }
    }

    $self->inspect_obj->{rules}->{ $self->rule_name }->{local} = $clean;
    $self->inspect_obj->{rules}->{ $self->rule_name }->{rule_keys} =
      dclone( $self->rule_keys );
    $self->get_line_number_rules;
    return $clean;
}

sub return_global_as_object {
    my $self = shift;

    $self->get_global_keys;

    my $attr = dclone( $self->global_attr );
    $attr->walk_process_data( $self->global_keys );

    my $global = {};

    foreach my $key ( @{ $self->global_keys } ) {
        $global->{$key} = $self->check_path( $attr->{$key} );
    }

    $self->inspect_obj->{global} = $global;
}

sub check_path {
    my $self = shift;
    my $val  = shift;

    if ( ref($val) eq 'Path::Tiny' ) {
        $val = $val->stringify;
    }
    return $val;
}

1;
