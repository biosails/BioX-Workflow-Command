package BioX::Workflow::Command::Exceptions;

use Moose;
use namespace::autoclean;

has 'message' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'Error was thrown.',
    documentation => 'This is a general message for the type of error thrown.'
);

has 'info' => (
    is            => 'rw',
    isa           => 'Str',
    required      => 0,
    documentation => 'Information specific to the error thrown',
    predicate     => 'has_info',
);

sub warn {
    my $self   = shift;
    my $logger = shift;

    if ($logger) {
        $logger->warn( $self->message );
        $logger->warn( $self->info ) if $self->has_info;
    }
    else {
        Core::warn $self->message;
        Core::warn $self->info  if $self->has_info;
    }
}

sub fatal {
    my $self   = shift;
    my $logger = shift;

    if ($logger) {
        $logger->fatal( $self->message );
        $logger->fatal( $self->info ) if $self->has_info;
    }
    else {
        Core::warn $self->message;
        Core::warn $self->info  if $self->has_info;
    }
}

1;
