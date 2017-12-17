package BioX::Workflow::Command::run::Rules::Exceptions::KeyDeclaration;

use Moose;
use namespace::autoclean;

extends 'BioX::Workflow::Command::Exceptions';

sub BUILD {
  my $self = shift;
  $self->message('Variable declarations should be in sequence/array format!');
}

1;
