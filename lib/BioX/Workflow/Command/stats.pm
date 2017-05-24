package BioX::Workflow::Command::stats;

use v5.10;
use MooseX::App::Command;
use Log::Log4perl qw(:easy);
use DateTime;
use Text::ASCIITable;
use Number::Bytes::Human qw(format_bytes parse_bytes);
use File::Details;
use File::Basename;

extends qw(  BioX::Workflow::Command );
use BioX::Workflow::Command::Utils::Traits qw(ArrayRefOfStrs);
use BioX::Workflow::Command::run::Utils::Directives;

with 'BioX::Workflow::Command::Utils::Log';
with 'BioX::Workflow::Command::run::Utils::Samples';
with 'BioX::Workflow::Command::run::Utils::Attributes';
with 'BioX::Workflow::Command::run::Utils::Rules';
with 'BioX::Workflow::Command::run::Utils::WriteMeta';
with 'BioX::Workflow::Command::run::Utils::Files::TrackChanges';
with 'BioX::Workflow::Command::run::Utils::Files::ResolveDeps';
with 'BioX::Workflow::Command::Utils::Files';
with 'BioX::Workflow::Command::Utils::Plugin';

command_short_description 'Get the status of INPUT/OUTPUT for your workflow';
command_long_description
  'If you are unsure on where you are in your workflow, run this step. '
  . 'It will give you a breakdown of rules with associated files, '
  . 'and whether or not they have been created or modified. '
  . 'Automatically select rules with unprocessed or changed files by using '
  . '--use_timestamps in your next run.';

has 'app_log_file' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self      = shift;
        my $dt        = DateTime->now( time_zone => 'local' );
        my $file_name = 'stats_' . $dt->ymd . '_' . $dt->time('-') . '.log';

        my $log_file =
          File::Spec->catdir( $self->cache_dir, 'logs', $file_name );
        return $log_file;
    }
);

has '+app_log' => (
    default => sub {
        my $self         = shift;
        my $app_log_file = $self->app_log_file;
        my $log_conf     = <<EOF;
  log4perl.category = DEBUG, LOGFILE
  log4perl.appender.LOGFILE=Log::Log4perl::Appender::File
  log4perl.appender.LOGFILE.filename=$app_log_file
EOF

        $log_conf .= <<'EOF';
  log4perl.appender.LOGFILE.mode=append
  log4perl.appender.LOGFILE.layout=PatternLayout
  log4perl.appender.LOGFILE.layout.ConversionPattern=[%d] %m %n
EOF

        Log::Log4perl->init( \$log_conf );
        return get_logger();
    },
);

has 'table_log' => (
    is      => 'rw',
    default => sub {
        my $self = shift;
        my $t    = Text::ASCIITable->new();
        $t->setCols( [ 'Rule', 'Sample', 'I/O', 'File', 'Exists', 'Size' ] );
        return $t;
    }
);

option 'use_full' => (
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => 'Use the full path name instead of the basename'
);

our $human = Number::Bytes::Human->new(
    bs          => 1024,
    round_style => 'round',
    precision   => 2
);

sub execute {
    my $self = shift;

    $self->stdout(1);
    if ( !$self->load_yaml_workflow ) {
        $self->app_log->warn('Exiting now.');
        return;
    }
    $self->apply_global_attributes;
    $self->get_global_keys;
    $self->get_samples;

    $self->iterate_rules;
    say $self->table_log;
}

around 'pre_FILES' => sub {
    my $orig = shift;
    my $self = shift;
    my $attr = shift;
    my $cond = shift;

    my $index =
      $self->first_index_select_rule_keys( sub { $_ eq $self->rule_name } );
    return if $index == -1;

    $self->$orig( $attr, $cond );

    for my $pair ( $self->files_pairs ) {
        $self->preprocess_row( $pair->[0], $cond );
    }
};

sub preprocess_row {
    my $self = shift;
    my $file = shift;
    my $cond = shift;

    $self->iter_file_samples( $file, $cond );
}

sub gen_row {
    my $self         = shift;
    my $file         = shift;
    my $cond         = shift;
    my $sample       = shift;
    my $sample_files = shift;

    foreach my $file (@$sample_files) {

        my @trow = ();

        push( @trow, $self->rule_name );
        push( @trow, $sample );
        push( @trow, $cond );

        my $rel = '';
        $rel = File::Spec->abs2rel($file) if $self->use_full;
        $rel = basename($file);

        #Add the filename
        push( @trow, $rel );

        #Does the file exist?
        if ( -e $file ) {
            push( @trow, 1 );

            #File Size
            my $details = File::Details->new($file);
            my $hsize   = $human->format( $details->size );
            push( @trow, $hsize );
        }
        else {
            push( @trow, 0 );
            push( @trow, '' );
        }
        $self->table_log->addRow( \@trow );
    }

}

sub iter_file_samples {
    my $self = shift;
    my $file = shift;
    my $cond = shift;

    my $dummy_sample = $self->dummy_sample;

    foreach my $sample ( $self->all_samples ) {
        my @sample_files = ();
        my $new_file     = $file;
        $new_file =~ s/$dummy_sample/$sample/g;
        my $chunk_files = $self->iter_file_chunks($new_file);

        if ($chunk_files) {
            map { push( @sample_files, $_ ) } @{$chunk_files};
        }
        else {
            push( @sample_files, $new_file );
        }
        $self->gen_row( $file, $cond, $sample, \@sample_files );
    }

}

sub iter_file_chunks {
    my $self = shift;
    my $file = shift;

    my @files    = ();
    my $use_iter = $self->use_iterables;

    return 0 if !$use_iter;

    my $all  = $use_iter->[0];
    my $elem = $use_iter->[1];

    my $dummy_iter = $self->dummy_iterable;
    foreach my $chunk ( $self->local_attr->$all ) {
        my $new_file = $file;
        $new_file =~ s/$dummy_iter/$chunk/g;
        push( @files, $new_file );
    }
    return \@files;
}

after 'template_process' => sub {
    my $self = shift;
    $self->table_log->addRowLine();
};

around 'print_process_workflow' => sub {
};

no Moose;
__PACKAGE__->meta->make_immutable;

1;
