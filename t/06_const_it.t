#!perl

use Test::More;
use strict;

use Config::Auto;

my $test_file = "/etc/fstab"; # A file found on any Unix/Linux machine.

SKIP: {
    skip "Can't test: $test_file doesn't exist on this system."
        unless -e $test_file;

    for ( 'bar' ) {
        eval { Config::Auto::parse($test_file); };
        ok( !$@,
            'Config::Auto:parse() where $_ aliases a string literal.' );
        diag($@) if $@;
    }
}

done_testing();
