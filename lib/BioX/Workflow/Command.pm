package BioX::Workflow::Command;

use v5.10;
our $VERSION = '2.0.2';

use MooseX::App qw(Color);
use MooseX::Types::Path::Tiny qw/Path/;
use Cwd qw(getcwd);
use File::Spec;
use File::Path qw(make_path);

app_strict 0;

# TODO move this after I have a better idea of where it is going
option 'cache_dir' => (
    is      => 'rw',
    isa     => Path,
    coerce  => 1,
    default => sub {
        return File::Spec->catfile( getcwd(), '.biox-cache' );
    },
    documentation =>
      'BioX-Workflow will cache some information during your runs. '
      . 'Delete with caution! '
      . '[Default: '.getcwd().'/biox-cache. ]'
);

sub BUILD { }

after 'BUILD' => sub {
    my $self = shift;

    make_path( $self->cache_dir );
};

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
