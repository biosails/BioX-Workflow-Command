#!/usr/bin/env perl
#

use Data::Dumper;
use CPAN::Meta;
use Module::CPANfile;


#Read MYMETA.json and creates a new cpanfile
my $meta = CPAN::Meta->load_file('META.json');
my $file = Module::CPANfile->from_prereqs($meta->prereqs);

 $file->save('cpanfile');
