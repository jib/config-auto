use Test::More tests => 5;

use strict;
use warnings;
no warnings qw(once);
use File::Spec::Functions;

my $Class = 'Config::Auto';

use_ok( $Class );

my $sub = $Class->can('parse');
my $config = $sub->( 'config.yml',   path => catdir('t','config') );

is( $Config::Auto::Format, 'yaml',
                                'Config file colon formatted');

ok( $config->{test},            "   Key 'test' exists" );
is( ref $config->{test}, 'HASH',"   It's a hash" );
is( $config->{test}{foo}, 'bar',"   With the proper value");
