use Test::More tests => 6;

use strict;
use warnings;
no warnings qw(once);

use File::Spec::Functions;

use_ok('Config::Auto');

my $config=Config::Auto::parse('colon.conf',path => catdir('t','config'));

is($Config::Auto::Format,'colon','Config file colon formatted');

is($config->{quux},'zoop');
is(ref $config->{test},'HASH');
is($config->{test}{foo},'bar');
is($config->{test}{baz},1);
