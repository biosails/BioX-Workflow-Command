package BioX::Workflow::Command;

use IO::Interactive;

use v5.10;
our $VERSION = '0.0.1';

use MooseX::App qw(Color);

app_strict 0;

no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=encoding utf-8

=head1 NAME

BioX::Workflow::Command - Blah blah blah

=head1 SYNOPSIS

  use BioX::Workflow::Command;

=head1 DESCRIPTION

BioX::Workflow::Command is

=head1 AUTHOR

Jillian Rowe E<lt>jillian.e.rowe@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2017- Jillian Rowe

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
