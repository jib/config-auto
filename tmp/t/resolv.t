use Test::More tests => 5;
use strict;
use warnings;
no warnings qw(once);

use File::Spec::Functions;

use_ok('Config::Auto');

my $config=Config::Auto::parse('resolv.conf',path => catdir('t','config'));

is($Config::Auto::Format,'space','Config file space formatted');
is(ref($config->{nameserver}),'ARRAY');
is($config->{nameserver}[0],'163.1.2.1');
is(ref($config->{search}),"ARRAY");

