package BioX::Workflow::Command::inspect::Utils::ParsePlainText;

use Moose::Role;
use namespace::autoclean;
use File::Slurp;

has 'workflow_plain_text' => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return read_file( $self->workflow, array_ref => 1 );
    }
);

has 'line_number_rules_dec' => (
    is      => 'rw',
    lazy    => 1,
    default => 1,
);

has 'line_number_global_dec' => (
    is      => 'rw',
    lazy    => 1,
    default => 2,
);

sub get_line_declarations {
    my $self = shift;

    my $line_number = 0;
    foreach my $line ( @{ $self->workflow_plain_text } ) {
        if ( $line =~ m/\s*:\s*rules\s*:/ ) {
            $self->line_number_rules_dec($line_number);
        }
        elsif ( $line =~ m/\s:\s*global\s:/ ) {
            $self->line_number_global_dec($line_number);
        }
        $line_number++;
    }
}

sub get_line_number_rules {
    my $self = shift;

    $self->inspect_obj->{line_numbers}->{rules}->{ $self->rule_name }->{local}
      = {};

    my $rule_name   = $self->rule_name;
    my $found_rule  = 0;
    my $found_local = 0;

    for (
        my $x = $self->line_number_rules_dec + 1 ;
        $x < scalar @{ $self->workflow_plain_text } ;
        $x++
      )
    {
        my $line = $self->workflow_plain_text->[$x];
        if ( $found_rule ) {
            $self->get_line_number_rule_key( $line, $x );
            $self->get_line_number_rule_process( $line, $x );
        }
        elsif ( ( $line =~ m/\s*-\s*$rule_name\s*:/ ) ) {
            $found_rule = 1;
        }
    }
}

sub get_line_number_rule_process {
    my $self       = shift;
    my $line       = shift;
    my $line_count = shift;

    return
      if
      exists $self->inspect_obj->{line_numbers}->{rules}->{ $self->rule_name }
      ->{process};

    if ( ( $line =~ m/\s*process\s*:/ ) ) {
        $self->inspect_obj->{line_numbers}->{rules}->{ $self->rule_name }
          ->{process} = $line_count;
        return;
    }
}

sub get_line_number_rule_key {
    my $self       = shift;
    my $line       = shift;
    my $line_count = shift;

    foreach my $key ( @{ $self->rule_keys } ) {
        next
          if exists $self->inspect_obj->{line_numbers}->{rules}
          ->{ $self->rule_name }->{local}->{$key};

        if ( ( $line =~ m/\s*-\s*$key\s*:/ ) ) {
            $self->inspect_obj->{line_numbers}->{rules}->{ $self->rule_name }
              ->{local}->{$key} = $line_count;
            return;
        }
    }
}

1;
