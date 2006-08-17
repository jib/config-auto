use Test::More;

use strict;
use warnings;
no warnings qw(once);

use File::Spec::Functions;

BEGIN {
  eval "use XML::Simple";

  plan skip_all => "XML::Simple required to test XML formatted configs" if $@;
  plan tests => 6;
}

use_ok('Config::Auto');

my $config=Config::Auto::parse('config.xml',path => catdir('t','config'));

is($Config::Auto::Format,'xml','Config file is XML');
is(ref $config->{main},'HASH','Parent element config');
is($config->{main}{title},'test blocks','Child element option');
is($config->{main}{name},'Tests & Failures','XML encoding');
is($config->{urlreader}{start},'home.html','Element with attribute');

