package BioX::Workflow::Command::run::Utils::WriteMeta;

use MooseX::App::Role;
use YAML;

=head1 BioX::Workflow::Command::run::Utils::WriteMeta;

Debug information containing metadata per rule.

Useful for tracking the evolution of an analysis

=head2 Variables

=head3 comment_char

Default comment char is '#'.

=cut

option 'comment_char' => (
    is      => 'rw',
    isa     => 'Str',
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

=head2 Subroutines

=cut

sub print_opts {
    my $self = shift;

    my $now = DateTime->now();
    $self->fh->say("#!/usr/bin/env bash\n\n");

    $self->fh->say("$self->{comment_char}");
    $self->fh->say("$self->{comment_char} Generated at: $now");
    $self->fh->say(
"$self->{comment_char} This file was generated with the following options"
    );

    for ( my $x = 0 ; $x <= $#ARGV ; $x++ ) {
        next unless $ARGV[$x];
        $self->fh->print("$self->{comment_char}\t$ARGV[$x]\t");
        if ( $ARGV[ $x + 1 ] ) {
            $self->fh->print( $ARGV[ $x + 1 ] );
        }
        $self->fh->print("\n");
        $x++;
    }

    $self->fh->say("$self->{comment_char}\n");
}

sub write_workflow_meta {
    my $self = shift;
    my $type = shift;

    return unless $self->verbose;

    if ( $type eq "start" ) {
        $self->fh->say("$self->{comment_char}\n");
        $self->fh->say("$self->{comment_char} Starting Workflow\n");
        $self->fh->say("$self->{comment_char}");
        $self->fh->say("$self->{comment_char}");
        $self->fh->say("$self->{comment_char} Global Variables:");

        foreach my $k ( $self->all_global_keys ) {
            next unless $k;
            my $v = $self->global_attr->$k;
            $self->fh->print( $self->write_pretty_meta( $k, $v ) );
        }
        $self->fh->say("$self->{comment_char}");
    }
    elsif ( $type eq "end" ) {
        $self->fh->say("$self->{comment_char}");
        $self->fh->say("$self->{comment_char} Ending Workflow");
        $self->fh->say("$self->{comment_char}");
    }
}

=head2 write_rule_meta

=cut

sub write_rule_meta {
    my $self = shift;
    my $meta = shift;

    $self->fh->say("\n$self->{comment_char}");

    if ( $meta eq "after_meta" ) {
        $self->fh->say("$self->{comment_char} Ending $self->{key}");
    }

    $self->fh->say("$self->{comment_char}\n");

    return unless $meta eq "before_meta";
    $self->fh->say("$self->{comment_char} Starting $self->{rule_name}");
    $self->fh->say("$self->{comment_char}\n");

    return unless $self->verbose;

    $self->fh->say("\n\n$self->{comment_char}");
    $self->fh->say("$self->{comment_char} Variables");
    $self->fh->say(
        "$self->{comment_char} Indir: " . $self->local_attr->indir );
    $self->fh->say(
        "$self->{comment_char} Outdir: " . $self->local_attr->outdir );

    if ( exists $self->local_rule->{ $self->rule_name }->{local} ) {

        $self->fh->say("$self->{comment_char} Local Variables:\n");

        foreach my $k ( $self->all_local_rule_keys ) {
            my ($v) = $self->local_attr->$k;
            $self->fh->print( $self->write_pretty_meta( $k, $v ) );
        }
    }

    $self->write_sample_meta if $self->resample;

    $self->fh->say("$self->{comment_char}\n\n");
}

=head2 write_sample_meta

Write the meta for samples

=cut

#TODO add in global file handle
#Should have opts for STDOUT, null, and an actual file

sub write_sample_meta {
    my $self = shift;

    return unless $self->verbose;

    $self->fh->say("$self->{comment_char}");
    $self->fh->print(
        "$self->{comment_char} Samples: ",
        join( ", ", @{ $self->samples } ) . "\n"
    );
    $self->fh->say("$self->{comment_char}\n");

}

sub write_pretty_meta {
    my $self = shift;
    my $k    = shift;
    my $v    = shift;

    my $t = '';
    if ( !ref($v) ) {
        $t = "$self->{comment_char}\t$k: " . $v . "\n";
    }
    else {
        $v = Dump($v);
        my %seen       = ();
        my @uniq_array = ();
        my @array      = split( "\n", $v );
        shift(@array);
        for ( my $x = 0 ; $x <= $#array ; $x++ ) {
            my $t = $self->comment_char . "\t\t" . $array[$x];
            next if $seen{$t};
            push( @uniq_array, $t );
            $seen{$t} = 1;
        }
        $v = join( "\n", @uniq_array );
        $t = "$self->{comment_char}\t$k:\n" . $v . "\n";
    }

    return $t;
}
1;
