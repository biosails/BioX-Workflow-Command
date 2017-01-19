package BioX::Workflow::Command::run::Utils::Directives;

use Moose;

use BioX::Workflow::Command::Utils::Traits qw(ArrayRefOfStrs);
use MooseX::Types::Path::Tiny qw/Path Paths AbsPath AbsFile/;
use Cwd qw(abs_path getcwd);

use Data::Walk;
use Text::Template;

use Data::Dumper;

use namespace::autoclean;

=head2 File Options

=head3 coerce_paths

Coerce relative path directories in variables: indir, outdir, and other variables ending in _dir to full path names

=cut

has 'coerce_paths' => (
    is        => 'rw',
    isa       => 'Bool',
    default   => 1,
    predicate => 'has_coerce_paths',
);

=head3 indir outdir

The initial indir is where samples are found

All output is written relative to the outdir

=cut

has 'indir' => (
    is            => 'rw',
    isa           => AbsPath,
    coerce        => 1,
    required      => 0,
    default       => sub { getcwd(); },
    predicate     => 'has_indir',
    clearer       => 'clear_indir',
    documentation => q(Directory to look for samples),
);

has 'outdir' => (
    is            => 'rw',
    isa           => AbsPath,
    coerce        => 1,
    required      => 0,
    default       => sub { getcwd(); },
    predicate     => 'has_outdir',
    clearer       => 'clear_outdir',
    documentation => q(Output directories for rules and processes),
);

=head3 INPUT OUTPUT

Special variables that can have input/output

=cut

has 'OUTPUT' => (
    is            => 'rw',
    isa           => 'Str|Undef',
    predicate     => 'has_OUTPUT',
    clearer       => 'clear_OUTPUT',
    documentation => q(At the end of each process the OUTPUT becomes
    the INPUT.)
);

has 'INPUT' => (
    is            => 'rw',
    isa           => 'Str|Undef',
    predicate     => 'has_INPUT',
    clearer       => 'clear_INPUT',
    documentation => q(See OUTPUT)
);

=head3 INPUTS OUTPUTS

Same as INPUT/OUTPUT, but in list format

=cut

has 'OUT_FILES' => (
    traits  => ['Array'],
    isa     => 'ArrayRef[AbsPath]',
    is      => 'rw',
    handles => {
        all_OUTPUTS   => 'elements',
        has_OUTPUTS   => 'count',
        clear_OUTPUTS => 'clear',
        join_OUTPUTS  => 'join',
    },
    default => sub { [] },
    documentation => 'See OUTPUT. This is the same, except in list format.',
);

has 'IN_FILES' => (
    traits  => ['Array'],
    isa     => 'ArrayRef[AbsPath]',
    is      => 'rw',
    default => sub { [] },
    handles => {
        all_INPUTS   => 'elements',
        has_INPUTS   => 'count',
        clear_INPUTS => 'clear',
        join_INPUTS  => 'join',
    },
    documentation => 'See INPUT. This is the same, except in list format.',
);

has 'DIRS' => (
    traits  => ['Array'],
    isa     => 'ArrayRef[AbsPath]',
    is      => 'rw',
    handles => {
        all_DIRS   => 'elements',
        has_DIRS   => 'count',
        clear_DIRS => 'clear',
        join_DIRS  => 'join',
    },
    default       => sub { [] },
    documentation => 'Dirs that are coerced to AbsPaths.',
);

=head3 create_outdir

=cut

has 'create_outdir' => (
    is        => 'rw',
    isa       => 'Bool',
    predicate => 'has_create_outdir',
    clearer   => 'clear_create_outdir',
    documentation =>
q(Create the outdir. You may want to turn this off if doing a rule that doesn't write anything, such as checking if files exist),
    default => 1,
);

=head2 Other Directives

=cut

has 'override_process' => (
    traits    => ['Bool'],
    is        => 'rw',
    isa       => 'Bool',
    default   => 0,
    predicate => 'has_override_process',
    documentation =>
      q(Instead of for my $sample (@sample){ DO STUFF } just DOSTUFF),
    handles => {
        set_override_process   => 'set',
        clear_override_process => 'unset',
    },
);

has 'sample' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_sample',
    clearer => 'clear_sample',
    required  => 0,
);

=head2 stash

This isn't ever used in the code. Its just there incase you want to persist objects across rules

It uses Moose::Meta::Attribute::Native::Trait::Hash and supports all the methods.

        set_stash     => 'set',
        get_stash     => 'get',
        has_no_stash => 'is_empty',
        num_stashs    => 'count',
        delete_stash  => 'delete',
        stash_pairs   => 'kv',

=cut

has 'stash' => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => ['Hash'],
    default => sub { {} },
    handles => {
        set_stash    => 'set',
        get_stash    => 'get',
        has_no_stash => 'is_empty',
        num_stashs   => 'count',
        delete_stash => 'delete',
        stash_pairs  => 'kv',
    },
);

=head3 create_attr

Add attributes to $self-> namespace

=cut

sub create_attr {
    my $self = shift;
    my $data = shift;

    my $meta = __PACKAGE__->meta;

    $meta->make_mutable;
    my $seen = {};

    for my $attr ( $meta->get_all_attributes ) {
        $seen->{ $attr->name } = 1;
    }

    #TODO Move this to a sanity check of the structure
    if ( !ref($data) eq 'ARRAY' ) {
        die print 'Your variable declarations should begin with an array!';
    }

    # Get workflow_data structure
    # Workflow is an array of hashes

    foreach my $href ( @{$data} ) {

        if ( !ref($href) eq 'HASH' ) {
            die print 'Your variable declarations should be key/value!';
        }

        while ( my ( $k, $v ) = each( %{$href} ) ) {

            if ( !exists $seen->{$k} ) {

                if ( $k =~ m/_dir$/ ) {
                    print "Creating an abs path $k\n";
                    $self->create_abs_path_attr( $meta, $k );
                }
                elsif ( ref($v) eq 'HASH' ) {
                    print "Creating an hash $k\n";
                    $self->create_HASH_attr( $meta, $k );
                }
                elsif ( ref($v) eq 'ARRAY' ) {
                    print "Creating an array $k\n";
                    $self->create_ARRAY_attr( $meta, $k );
                }
                else {
                    print "Creating a regular attr $k\n";
                    $self->create_reg_attr( $meta, $k );
                }
            }

            $self->$k($v) if defined $v;
        }

    }

    $meta->make_immutable;
}

sub create_abs_path_attr {
    my $self = shift;
    my $meta = shift;
    my $k    = shift;

    my $coerce = 0;
    $coerce = 1 if $self->coerce_paths;

    $meta->add_attribute(
        $k => (
            is        => 'rw',
            isa       => AbsPath,
            coerce    => $coerce,
            predicate => "has_$k",
            clearer   => "clear_$k"
        )
    );
}

sub create_ARRAY_attr {
    my $self = shift;
    my $meta = shift;
    my $k    = shift;

    $meta->add_attribute(
        $k => (
            traits  => ['Array'],
            isa     => 'ArrayRef',
            is      => 'rw',
            clearer => "clear_$k",
            default => sub { [] },
            handles => {
                "all_$k"    => 'elements',
                "count_$k"  => 'count',
                "has_$k"    => 'count',
                "has_no_$k" => 'is_empty',
            },
        )
    );
}

sub create_HASH_attr {
    my $self = shift;
    my $meta = shift;
    my $k    = shift;

    $meta->add_attribute(
        $k => (
            traits  => ['Hash'],
            isa     => 'HashRef',
            is      => 'rw',
            clearer => "clear_$k",
            default => sub { {} },
            handles => {
                "get_$k"        => 'get',
                "has_no_$k"     => 'is_empty',
                "num_$k"        => 'count',
                "$k" . "_pairs" => 'kv',
            },
        )
    );
}

sub create_reg_attr {
    my $self = shift;
    my $meta = shift;
    my $k    = shift;

    $meta->add_attribute(
        $k => (
            is        => 'rw',
            predicate => "has_$k",
            clearer   => "clear_$k"
        )
    );
}

sub interpol_directive {
    my $self   = shift;
    my $source = shift;


    my $template = Text::Template->new(
        TYPE   => 'STRING',
        SOURCE => $source,
    );

    my $fill_in = { self => \$self };
    $fill_in->{sample} = $self->sample if $self->has_sample;

    my $text = $template->fill_in( HASH => $fill_in );

    return $text;
}

=head3 walk_directives

Invoke with
  walk { wanted => sub { $self->do_something(@_) } }, $self->other_thing;

=cut

sub walk_directives {
    my $self = shift;
    my $ref  = $_;

    return if ref($ref);

    my $text      = $self->interpol_directive($ref);
    my $container = $Data::Walk::container;
    my $key       = $Data::Walk::key;
    my $index     = $Data::Walk::index;

    if ( $Data::Walk::type eq 'HASH' && $key ) {
        $container->{$key} = $text;
    }
    elsif ( $Data::Walk::type eq 'ARRAY' ) {
        $container->[$index] = $text;
    }
    else {
        #We should raise some warnings here...
    }

    return;
}

1;
