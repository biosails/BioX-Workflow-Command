package BioX::Workflow::Command::run::Rules::Directives::MCE;

use Moose::Role;
use namespace::autoclean;

use MCE;
use MCE::Queue;
use MCE::Shared;

=head2 Attributes

=cut

has 'texts' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub {
        return [];
    }
);

has 'procs' => (
    is      => 'rw',
    default => 4,
);

has 'queue' => (
    is      => 'rw',
    lazy    => 0, ## must be 0 to ensure the queue is created prior to spawning
    default => sub {
        my $self = shift;
        return MCE::Queue->new(
            queue  => [],
        );
    }
);

has 'mce' => (
    is      => 'rw',
    lazy    => 1,
    clearer => '_clear_mce',
    default => sub {
        my $self = shift;
        return MCE->new(
            use_threads => 0,
            gather => sub {$self->gather(@_)},
            user_func   => sub {
                my $mce = shift;
                my @a;
                while (1) {
                    my ($counter, $data) = $self->queue->dequeue(2);
                    last unless defined $counter;
                    $self->counter($counter);
                    $self->run_cmd_mce($data);
                }
            }
        );
    }
);

has 'counter' => (
    traits   => [ 'Counter' ],
    is       => 'rw',
    isa      => 'Num',
    required => 1,
    default  => 1,
    handles  => {
        inc_counter   => 'inc',
        dec_counter   => 'dec',
        reset_counter => 'reset',
    },
);

##Callback in moose looks like this
#sub { $self->walk_directives(@_)
sub run_cmd_mce {
    my $self = shift;
    my $data = shift;
    print "HELLO from " . $self->counter . "\n";
    return 1;
}

sub gather {
    my $self = shift;
    my $args = shift;
    my $other_args = shift;

    print "Hello from gather!\n\n";
    use Data::Dumper;
    print "\n\n";
}



1;
