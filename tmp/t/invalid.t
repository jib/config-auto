use Test::More tests => 4;
use strict;
use warnings;
use Data::Dumper;
no warnings qw(once);


my $Class   = 'Config::Auto';
my $Method  = 'score';
my @Data    =  split $/, <<'.';
[part one]
This: is garbage
.

use_ok( $Class );

{   my $warnings = '';
    local $SIG{__WARN__} = sub { $warnings .= "@_" };
    
    my %rv = $Class->can($Method)->( \@Data );
    
    ok( 1,                      "Testing invalid dataset '@Data'" );
    ok( scalar(keys %rv),       "   Got return value from '$Method'" );
    is( $warnings, '',          "   No warnings recorded" );
}    
    
