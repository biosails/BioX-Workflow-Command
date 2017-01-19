package TestMethod::Base;

use Test::Class::Moose;
use FindBin qw($Bin);
use File::Path qw(make_path remove_tree);

sub make_test_dir{

    my $test_dir;

    my @chars = ('a'..'z', 'A'..'Z', 0..9);
    my $string = join '', map { @chars[rand @chars]  } 1 .. 8;

    if(exists $ENV{'TMP'}){
        $test_dir = $ENV{TMP}."/bioxworkflow/$string";
    }
    else{
        $test_dir = "/tmp/bioxworkflow/$string";
    }

    remove_tree($test_dir);
    make_path($test_dir);
    make_path($test_dir."/data/raw");
    make_path($test_dir."/data/analysis");
    make_path($test_dir."/conf");

    chdir($test_dir);

    return $test_dir;
}

sub test_shutdown {

    chdir("$Bin");

    if ( exists $ENV{'TMP'} ) {
        remove_tree( $ENV{TMP} . "/bioxworkflow" );
    }
    else {
        remove_tree("/tmp/bioxworkflow");
    }
}

sub print_diff {
    my $got    = shift;
    my $expect = shift;

    use Text::Diff;

    my $diff = diff \$got, \$expect;
    diag("Diff is\n\n$diff\n\n");

    my $fh;
    open( $fh, ">got.diff" ) or die print "Couldn't open $!\n";
    print $fh $got;
    close($fh);

    open( $fh, ">expect.diff" ) or die print "Couldn't open $!\n";
    print $fh $expect;
    close($fh);

    open( $fh, ">diff.diff" ) or die print "Couldn't open $!\n";
    print $fh $diff;
    close($fh);

    ok(1);
}

1;
