package BioX::Workflow::Command::run::Utils::WriteMeta;

use MooseX::App::Role;

=head1 BioX::Workflow::Command::run::Utils::WriteMeta;

Debug information containing metadata per rule.

Useful for tracking the evolution of an analysis

=head2 Variables

=head3 comment_char

Default comment char is '#'.

=cut

option 'comment_char' => (
  is => 'rw',
  isa => 'Str',
  default => '#',
);

=head3 verbose

Output some more things

=cut

option 'verbose' => (
    is        => 'rw',
    isa       => 'Bool',
    default   => 1,
    clearer   => 'clear_verbose',
    predicate => 'has_verbose',
);

=head3 wait

=cut

has 'wait' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
    documentation =>
        q(Print 'wait' at the end of each rule. If you are running as a plain bash script you probably don't need this.),
    clearer   => 'clear_wait',
    predicate => 'has_wait',
);

=head2 Subroutines

=cut

sub write_workflow_meta {
    my $self = shift;
    my $type = shift;

    return unless $self->verbose;

    if ( $type eq "start" ) {
        print "$self->{comment_char}\n";
        print "$self->{comment_char} Starting Workflow\n";
        print "$self->{comment_char}\n";
        print "$self->{comment_char}\n";
        print "$self->{comment_char} Global Variables:\n";

        my @keys = $self->global_attr->get_keys();

        foreach my $k (@keys) {
            next unless $k;
            my ($v) = $self->global_attr->get_values($k);
            print "$self->{comment_char}\t$k: " . $v . "\n";
        }
        print "$self->{comment_char}\n";
    }
    elsif ( $type eq "end" ) {
        print "$self->{comment_char}\n";
        print "$self->{comment_char} Ending Workflow\n";
        print "$self->{comment_char}\n";
    }
}

=head2 write_rule_meta

=cut

sub write_rule_meta {
    my ( $self, $meta ) = @_;

    print "\n$self->{comment_char}\n";

    if ( $meta eq "after_meta" ) {
        print "$self->{comment_char} Ending $self->{key}\n";
    }

    print "$self->{comment_char}\n\n";

    return unless $meta eq "before_meta";
    print "$self->{comment_char} Starting $self->{key}\n";
    print "$self->{comment_char}\n\n";

    return unless $self->verbose;

    print "\n\n$self->{comment_char}\n";
    print "$self->{comment_char} Variables \n";
    print "$self->{comment_char} Indir: " . $self->indir . "\n";
    print "$self->{comment_char} Outdir: " . $self->outdir . "\n";

    if ( exists $self->local_rule->{ $self->key }->{local} ) {

        print "$self->{comment_char} Local Variables:\n";

        my @keys = $self->local_attr->get_keys();

        foreach my $k (@keys) {
            my ($v) = $self->local_attr->get_values($k);
            print "$self->{comment_char}\t$k: " . $v . "\n";
        }
    }

    $self->write_sample_meta if $self->resample;

    print "$self->{comment_char}\n\n";
}

=head2 write_sample_meta

Write the meta for samples

=cut

#TODO add in global file handle
#Should have opts for STDOUT, null, and an actual file

sub write_sample_meta {
    my $self = shift;

    return unless $self->verbose;

    print "$self->{comment_char}\n";
    print "$self->{comment_char} Samples: ",
        join( ", ", @{ $self->samples } ) . "\n";
    print "$self->{comment_char}\n";

}


1;
