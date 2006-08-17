use Test::More tests => 7;
use strict;
use warnings;
no warnings qw(once);

use File::Spec::Functions;
use_ok('Config::Auto');

my $config = Config::Auto::parse('win.ini',path => catdir('t','config'));

is($Config::Auto::Format,'ini','Config file ini formatted');
is(ref($config->{group1}),'HASH','Data structure');
is($config->{group1}{host},'proxy.some-domain-name.com','host name');
is($config->{group1}{port},'80','port');
is($config->{group1}{username},'blah','username');
is($config->{group1}{password},'doubleblah','password');

