use Test::More tests => 4;
use strict;
use warnings;
no warnings qw(once);

use File::Spec::Functions;

use_ok ('Config::Auto');

my $config=Config::Auto::parse('nsswitch.conf',path => catdir('t','config'));
is($Config::Auto::Format,'colon','Config file colon formatted');
is($config->{passwd},'compat');
is(ref($config->{hosts}),'ARRAY');
