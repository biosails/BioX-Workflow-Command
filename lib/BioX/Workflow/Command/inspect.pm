package BioX::Workflow::Command::inspect;

use v5.10;
use MooseX::App::Command;
use namespace::autoclean;

use Data::Dumper;
use File::Path qw(make_path);
use Storable qw(dclone);

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
with 'BioSAILs::Utils::Files::CacheDir';
with 'BioSAILs::Utils::CacheUtils';

use BioX::Workflow::Command::run;

command_short_description 'Inspect your workflow';
command_long_description
'Inspect individual variables in your workflow. Syntax is global.var for global, or rule.rulename.var for rules. Use the --all flag to inspect all variables.';

=head1 BioX::Workflow::Command::inspect

  biox inspect -h
  biox inspect -w variant_calling.yml

=cut

=head2 Attributes

=cut

option 'all' => (
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

    $self->apply_global_attributes;
    $self->get_global_keys;
    $self->get_samples;

    $self->set_rule_names;
    my $rules = $self->workflow_data->{rules};

    $self->filter_rule_keys;

    foreach my $rule (@$rules) {

        $self->local_rule($rule);
        $self->process_rule;
        $self->p_rule_name( $self->rule_name );
        $self->p_local_attr( dclone( $self->local_attr ) );

        # $self->sample('Sample_XYZ');
        ##This is the inspect part
        ## Also need to add the error part
        # $self->return_as_obj( $self->rule_keys, $self->local_attr );
    }
}

# sub eval_process {
#     my $self = shift;
#
#     my $attr = $self->walk_attr;
#     # $attr->sample( $self->sample ) if $self->has_sample;
#     $attr->sample('Sample_XYZ');
#
#     $self->walk_indir_outdir($attr);
#
#     my $text = $self->eval_rule($attr);
#     $text = clean_text($text);
#
#     $self->walk_FILES($attr);
#     $self->clear_files;
#
#     ##Carry stash when not in template
#
#     print "In my Eval Process\n";
#     # print Dumper($attr);
#     # print "TExt is $text\n";
#     $self->local_attr->stash( dclone( $attr->stash ) );
#
#     my $indir = $attr->interpol_directive($attr->indir);
#     use Data::Dumper;
#     print Dumper($attr);
#     print "INDIR IS $indir\n";
#
#     return $text;
# }

sub return_as_obj {
    my $self      = shift;
    my $rule_keys = shift;
    my $attr      = shift;

    my %hacky_self = %{$attr};
    foreach my $remove ( @{ $self->remove_from_json } ) {
        delete $hacky_self{$remove};
    }

    my $clean = {};
    foreach my $key ( @{$rule_keys} ) {
        $clean->{$key} = $attr->$key;
    }
    my @haves = ( 'indir', 'outdir', 'INPUT', 'OUTPUT' );
    foreach my $h (@haves) {
        if ( !exists $clean->{$h} ) {
            $clean->{$h} = $attr->$h;
        }
    }

    return $clean;
}

1;
