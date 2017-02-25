requires 'Class::Load';
requires 'Config::Any';
requires 'Cwd';
requires 'Data::Dumper';
requires 'Data::Merger';
requires 'Data::Walk';
requires 'DateTime';
requires 'File::Basename';
requires 'File::Find::Rule';
requires 'File::Path';
requires 'File::Spec';
requires 'IO::File';
requires 'List::Compare';
requires 'List::Uniq';
requires 'Log::Log4perl';
requires 'Memoize';
requires 'Moose';
requires 'Moose::Role';
requires 'Moose::Util::TypeConstraints';
requires 'MooseX::App';
requires 'MooseX::App::Command';
requires 'MooseX::App::Role';
requires 'MooseX::Types';
requires 'MooseX::Types::Moose';
requires 'MooseX::Types::Path::Tiny';
requires 'Path::Tiny';
requires 'Safe';
requires 'Scalar::Util';
requires 'Storable';
requires 'Text::Template';
requires 'Try::Tiny';
requires 'YAML';
requires 'YAML::XS';
requires 'namespace::autoclean';
requires 'perl', 'v5.10.0';
requires 'utf8';

on configure => sub {
    requires 'Module::Build::Tiny', '0.034';
};

on test => sub {
    requires 'Capture::Tiny';
    requires 'File::Spec::Functions';
    requires 'FindBin';
    requires 'Test::Class::Moose';
    requires 'Test::Class::Moose::Load';
    requires 'Test::Class::Moose::Runner';
    requires 'Test::More', '0.96';
    requires 'Text::Diff';
    requires 'strict';
};

on develop => sub {
    requires 'Dist::Milla', 'v1.0.17';
    requires 'Test::Pod', '1.41';
};
