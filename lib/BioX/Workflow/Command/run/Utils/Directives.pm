package BioX::Workflow::Command::run::Utils::Directives;

use Moose;

use BioX::Workflow::Command::Utils::Traits qw(ArrayRefOfStrs);
use MooseX::Types::Path::Tiny qw/Path Paths AbsPath AbsFile/;
use Cwd qw(abs_path getcwd);
use Path::Tiny;
use Data::Merger qw(merger);
use Data::Walk;
use Text::Template;
use Data::Dumper;
use Scalar::Util 'blessed';
use Try::Tiny;
use Safe;

# use File::Basename;
use File::Spec;

use Moose::Util::TypeConstraints;
class_type 'Path';
class_type 'Paths';

use Memoize;

memoize('my_broken');
memoize('interpol_directive');

use namespace::autoclean;

=head2 File Options

=head3 indir outdir

The initial indir is where samples are found

All output is written relative to the outdir

=cut

has 'indir' => (
    is            => 'rw',
    isa           => Path,
    coerce        => 1,
    required      => 0,
    default       => sub { getcwd(); },
    predicate     => 'has_indir',
    clearer       => 'clear_indir',
    documentation => q(Directory to look for samples),
);

has 'outdir' => (
    is            => 'rw',
    isa           => Path,
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
    required      => 0,
    predicate     => 'has_OUTPUT',
    documentation => q(At the end of each process the OUTPUT becomes
    the INPUT.)
);

has 'INPUT' => (
    is            => 'rw',
    required      => 0,
    predicate     => 'has_INPUT',
    documentation => q(See OUTPUT)
);

=head2 sample_bydir

Use this option when you sample names are by directory
The default is to find samples by filename

    /SAMPLE1
        SAMPLE1_r1.fastq.gz
        SAMPLE1_r2.fastq.gz
    /SAMPLE2
        SAMPLE2_r1.fastq.gz
        SAMPLE2_r2.fastq.gz

=cut

has 'sample_bydir' => (
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => q{Use this option when you sample names are directories},
    predicate     => 'has_sample_bydir',
    clearer       => 'clear_sample_bydir',
);

=head3 by_sample_outdir

=cut

has 'by_sample_outdir' => (
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => q{Use this option when you sample names are directories},
    predicate     => 'has_by_sample_outdir',
    clearer       => 'clear_by_sample_outdir',
);

=head3 coerce_abs_dir

Coerce dirs to absolute paths (True)
Keep paths as relative directories (False)

=cut

has 'coerce_abs_dir' => (
    is            => 'rw',
    isa           => 'Bool',
    default       => 1,
    documentation => q{Coerce '*_dir' to absolute directories},
    predicate     => 'has_coerce_abs_dir',
    clearer       => 'clear_coerce_abs_dir',
);

=head3 INPUTS OUTPUTS

Same as INPUT/OUTPUT, but in list format

=cut

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

has 'samples' => (
    traits        => ['Array'],
    is            => 'rw',
    required      => 0,
    isa           => ArrayRefOfStrs,
    documentation => 'Choose a subset of samples',
    default       => sub { [] },
    handles       => {
        all_samples  => 'elements',
        has_samples  => 'count',
        join_samples => 'join',
    },
);

has 'sample' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_sample',
    clearer   => 'clear_sample',
    required  => 0,
);

has 'errors' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has 'is_select' => (
    traits => ['Bool'],
    isa     => 'Bool',
    is      => 'rw',
    default => 1,
    handles => {
      deselect => 'unset',
      select => 'set',
    },
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
        next if $attr->name eq 'stash';
        $seen->{ $attr->name } = 1;
    }

    # Get workflow_data structure
    # Workflow is an array of hashes

    foreach my $href ( @{$data} ) {

        if ( !ref($href) eq 'HASH' ) {

            #TODO add more informative structure options here
            warn 'Your variable declarations should be key/value!';
            return;
        }

        while ( my ( $k, $v ) = each( %{$href} ) ) {

            if ( !exists $seen->{$k} ) {

                if ( $k eq 'stash' ) {
                    $self->merge_stash($v);
                }
                elsif ( ref($v) eq 'HASH' ) {
                    $self->create_HASH_attr( $meta, $k );
                }
                elsif ( ref($v) eq 'ARRAY' ) {
                    $self->create_ARRAY_attr( $meta, $k );
                }
                else {
                    $self->create_reg_attr( $meta, $k );
                }
            }

            $self->$k($v) if defined $v;
        }

    }

    $meta->make_immutable;
}

sub merge_stash {
    my $self   = shift;
    my $target = shift;

    my $merged_data = merger( $target, $self->stash );
    $self->stash($merged_data);
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
            is         => 'rw',
            lazy_build => 1,
        )
    );
}

sub interpol_directive {
    my $self   = shift;
    my $source = shift;
    my $text   = '';

    if ( !$source ) {
        return '';
    }

    my $c        = new Safe;
    my $template = Text::Template->new(
        TYPE   => 'STRING',
        SOURCE => $source,
        SAFE   => $c,
    );

    my $fill_in = { self => \$self };
    $fill_in->{sample} = $self->sample if $self->has_sample;

    $text = $template->fill_in( HASH => $fill_in, BROKEN => \&my_broken );

    return $text;
}

sub my_broken {
    my %args    = @_;
    my $err_ref = $args{arg};
    my $text    = $args{text};
    my $error   = $args{error};
    $error =~ s/via package.*//g;
    chomp($error);
    if ( $error =~ m/Can't locate object method/ ) {
        $error .= "\n# Did you declare $text?";
    }

    return <<EOF;

###################################################
# The following errors were encountered:
# $text
# $error
###################################################
EOF
}

sub walk_process_data {
    my $self = shift;
    my $keys = shift;

    foreach my $k ( @{$keys} ) {
        next if ref($k);
        my $v = $self->$k;
        if ( $k eq 'OUTPUT' || $k eq 'INPUT' || $k =~ m/_dir$/ ) {
            $self->process_directive( $k, $v, 1 );
        }
        elsif ( $k eq 'indir' || $k eq 'outdir' ) {
            $self->process_directive( $k, $v, 1 );
        }
        else {
            $self->process_directive( $k, $v, 0 );
        }
    }
}

=head3 process_directive

=cut

sub process_directive {
    my $self = shift;
    my $k    = shift;
    my $v    = shift;
    my $path = shift;

    if ( ref($v) ) {
        walk {
            wanted => sub { $self->walk_directives( @_, $path ) }
          },
          $self->$k;
    }
    else {
        my $text = $self->interpol_directive($v);
        if ( $path && $text ne '' ) {
            $text = path($text)->absolute if $self->coerce_abs_dir;
            $self->$k("$text");
            return;
        }

        $self->$k($text);
    }
}

#TODO See if we can combine these to one

=head3 walk_directives

Invoke with
  walk { wanted => sub { $self->directives(@_) } }, $self->other_thing;

Acts funny with $self->some_other_thing is not a reference

=cut

sub walk_directives {
    my $self = shift;
    my $ref  = shift;
    my $path = shift;

    return if ref($ref);
    return unless $ref;

    my $text = $self->interpol_directive($ref);
    if ($path) {
        $text = path($text)->absolute if $self->coerce_abs_dir;
        $text = "$text";
    }

    $self->update_directive($text);
}


=head3 update_directive

Take the values from walk_directive and update the directive

=cut

sub update_directive {
    my $self = shift;
    my $text = shift;

    my ( $key, $container, $index );

    $container = $Data::Walk::container;
    $key       = $Data::Walk::key;
    $index     = $Data::Walk::index;

    if ( $Data::Walk::type eq 'HASH' && $key ) {
        $container->{$key} = $text;
    }
    elsif ( $Data::Walk::type eq 'ARRAY' ) {
        $container->[$index] = $text;
    }
    else {
        #We are getting the whole hash, just return
        return;
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;