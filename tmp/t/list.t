use Test::More tests => 6;

use strict;
use warnings;
no warnings qw(once);

use File::Spec::Functions;

use_ok('Config::Auto');

my $config = Config::Auto::parse('list.conf',path => catdir('t','config'));

is($Config::Auto::Format,'space','Config file colon formatted');

my $aref = $config->{set};

ok( $aref,                      "Config item 'set' retrieved" );
isa_ok( $aref,                  'ARRAY' );
is( scalar @$aref, 2,           "   2 items found" );
is_deeply( $aref, ['foo', 'bar, baby'],
                                "   correct contents" );
