use Test::More tests => 4;

use strict;
use warnings;
no warnings qw(once);

use File::Spec::Functions;

use_ok('Config::Auto');

my $config=Config::Auto::parse('deb.conf',path => catdir('t','config'));

is($Config::Auto::Format,'equal','Config file equal formatted');
is($config->{MOZILLA_DSP},'auto');
is($config->{USE_GDKXFT},'false');
