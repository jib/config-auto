use strict;
use warnings;
use Test::More 'no_plan';

### whitebox test, disabling XML::Simple
{   package XML::Simple;
    $INC{'XML/Simple.pm'} = $0;
    
    sub import { die };
}

my $Class = 'Config::Auto';

use_ok( $Class );

{   my $obj = $Class->new( source => $$.$/, format => 'xml' );
    ok( $obj,                   "Object created" );
    
    eval { $obj->parse }; 
    ok( $@,                     "parse() on xml dies without XML::Simple" );
    like( $@, qr/XML::Simple/,  "   Error message is informative" );
}
