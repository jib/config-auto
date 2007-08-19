use Test::More tests => 3;
use strict;
use warnings;
use File::Spec::Functions;

### whitebox test, disabling XML::Simple
{   package XML::Simple;
    $INC{'XML/Simple.pm'} = $0;
    
    sub import { die };
}

use_ok('Config::Auto');

eval { Config::Auto::parse(
            'config.xml',path => catdir('t','config')
        );
};

ok( $@,                     "parse() on xml dies without XML::Simple" );
like( $@, qr/XML::Simple/,  "   Error message is informative" );
