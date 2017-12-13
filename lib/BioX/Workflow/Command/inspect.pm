package BioX::Workflow::Command::inspect;

use v5.10;
use MooseX::App::Command;
use namespace::autoclean;

use File::Path qw(make_path);

extends 'BioX::Workflow::Command';
use BioSAILs::Utils::Traits qw(ArrayRefOfStrs);

# with 'BioX::Workflow::Command::run::Utils::Samples';
# use BioX::Workflow::Command::run::Rules::Directives;

# with 'BioX::Workflow::Command::run::Utils::Attributes';
# with 'BioX::Workflow::Command::run::Rules::Rules';
# with 'BioX::Workflow::Command::run::Utils::WriteMeta';
# with 'BioX::Workflow::Command::run::Utils::Files::TrackChanges';
# with 'BioX::Workflow::Command::run::Utils::Files::ResolveDeps';
# with 'BioX::Workflow::Command::Utils::Files';
# with 'BioSAILs::Utils::Files::CacheDir';
# with 'BioSAILs::Utils::CacheUtils';

command_short_description 'Inspect your workflow';
command_long_description
  'Inspect individual variables in your workflow. Syntax is global.var for global, or rule.rulename.var for rules. Use the --all flag to inspect all variables.';

=head1 BioX::Workflow::Command::

  biox inspect -h
  biox inspect -w variant_calling.yml

=cut

=head2 Attributes

=cut

option 'all' => (
  is => 'rw',
  isa => 'Bool',
  default => 0,
);

=head2 Subroutines

=cut


1;
