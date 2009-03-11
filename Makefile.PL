use ExtUtils::MakeMaker;

use strict;
use Getopt::Std;
use Data::Dumper;
my $opts = {};
getopts( 'x', $opts );

my $have_xml_simple = eval { require XML::Simple; 1; };

if( !$have_xml_simple and !$opts->{'x'} ) {
    warn qq[Since the 0.04 release, XML::Simple is an optional prerequisite.\n].
         qq[If you'd like to install Config::Auto with XML support, please\n] .
         qq[rerun this Makefile.PL with the '-x' option\n];
}

my $prereqs = {
    'XML::Simple'           => 0,
    'YAML'                  => 0.67,
    'Config::IniFiles'      => 0,
    'File::Spec::Functions' => 0,
    'Test::More'            => 0,
    'Text::ParseWords'      => 0,
    'File::Temp'            => 0,
    'IO::String'            => 0,
};
delete $prereqs->{'XML::Simple'} unless $opts->{'x'};             

WriteMakefile(
    'NAME'		        => 'Config::Auto',
    'VERSION_FROM'	    => 'lib/Config/Auto.pm', # finds $VERSION
    'PREREQ_PM'		    => $prereqs, 
    ( $] >= 5.005 
        ? ( ABSTRACT_FROM    => 'lib/Config/Auto.pm', 
            AUTHOR           => 'Jos I. Boumans <kane@cpan.org>') 
        : ()
    ),
);
