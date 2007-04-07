package Config::Auto;

use strict;
use warnings;
use File::Spec::Functions;
use File::Basename;
#use XML::Simple;   # this is now optional
use Config::IniFiles;
use Carp;

use vars qw[$VERSION $DisablePerl $Untaint $Format];

$VERSION = '0.20';
$DisablePerl = 0;
$Untaint = 0;

my %methods = (
    perl   => \&eval_perl,
    colon  => \&colon_sep,
    space  => \&space_sep,
    equal  => \&equal_sep,
    bind   => \&bind_style,
    irssi  => \&irssi_style,
    xml    => \&parse_xml,
    ini    => \&parse_ini,
    list   => \&return_list,
    yaml   => \&yaml,
);

### make sure we give good diagnostics when XML::Simple is not available,
### but required to parse a config
$methods{'xml'} = sub { croak "XML::Simple not available. Can not parse '@_'" }
    unless eval { require XML::Simple; XML::Simple->import; 1 };

sub parse {
    my $file = shift;
    my %args = @_;

    $file = find_file($file,$args{path})    if not defined $file or 
                                                not -e $file;
    croak "No config file found!"           if not defined $file;
    croak "Config file $file not readable!" if not -e $file;

    
    ### from Toru Marumoto: Config-Auto return undef if -B $file     
    ### <21d48be50604271656n153e6db6m9b059f57548aaa32@mail.gmail.com>
    # If a config file "$file" contains multibyte charactors like japanese,
    # -B returns "true" in old version of perl such as 5.005_003. It seems
    # there is no problem in perl 5.6x or older.
    ### so check -B and only return only if 
    return if -B $file and $] >= '5.006';

    my $method;
    my @data;

    if (!defined $args{format}) {
        # OK, let's take a look at you.
        my @data;
        open my $config, $file or croak "$file: $!";
        if (-s $file > 1024*100) {
            # Just read in a bit.
            while (<$config>) {
                push @data, $_;
                last if $. >= 50;
            }
        } else {
            @data = <$config>;
        }
        my %scores = score(\@data);

        delete $scores{perl} if exists $scores{perl} and $DisablePerl;
        croak "Unparsable file format!" if !keys %scores;
        # Clear winner?
        my @methods = sort { $scores{$b} <=> $scores{$a} } keys %scores;
        if (@methods > 1) {
            croak "File format unclear! ".join ",", map { "$_ => $scores{$_}"} @methods
               if $scores{$methods[0]} == $scores{$methods[1]};
        }
        $method = $methods[0];
    } else {
        croak "Unknown format $args{format}: use one of @{[ keys %methods ]}"
            if not exists $methods{ lc $args{format} };
        $method = lc $args{format};
    }

    $Format = $method;
    return $methods{$method}->($file);
}

sub score {
    my $data_r = shift;
    return (xml => 100)     if $data_r->[0] =~ /^\s*<\?xml/;
    return (perl => 100)    if $data_r->[0] =~ /^#!.*perl/;
    my %score;

    for (@$data_r) {
        ### it's almost definately YAML if the first line matches this
        $score{yaml} += 20              if /(?:\#|%)    # a #YAML or %YAML
                                            YAML
                                            (?::|\s)    # a YAML: or YAML[space]
                                        /x and $data_r->[0] eq $_;
        $score{yaml} += 20              if /^---/ and $data_r->[0] eq $_;   
        $score{yaml} += 10              if /^\s+-\s\w+:\s\w+/;
        
        # Easy to comment out foo=bar syntax
        $score{equal}++                 if /^\s*#\s*\w+\s*=/;
        next if /^\s*#/;

        $score{xml}++                   for /(<\w+.*?>)/g;
        $score{xml}+= 2                 for m|(</\w+.*?>)|g;
        $score{xml}+= 5                 for m|(/>)|g;
        next unless /\S/;

        $score{equal}++, $score{ini}++  if m|^.*=.*$|;
        $score{equal}++, $score{ini}++  if m|^\S+\s+=\s+|;
        $score{colon}++                 if /^[^:]+:[^:=]+/;
        $score{colon}+=2                if /^\s*\w+\s*:[^:]+$/;
        $score{colonequal}+= 3          if /^\s*\w+\s*:=[^:]+$/; # Debian foo.
        $score{perl}+= 10               if /^\s*\$\w+(\{.*?\})*\s*=.*/;
        $score{space}++                 if m|^[^\s:]+\s+\S+$|;

        # mtab, fstab, etc.
        $score{space}++                 if m|^(\S+)\s+(\S+\s*)+|;
        $score{bind}+= 5                if /\s*\S+\s*{$/;
        $score{list}++                  if /^[\w\/\-\+]+$/;
        $score{bind}+= 5                if /^\s*}\s*$/  and exists $score{bind};
        $score{irssi}+= 5               if /^\s*};\s*$/ and exists $score{irssi};
        $score{irssi}+= 10              if /(\s*|^)\w+\s*=\s*{/;
        $score{perl}++                  if /\b([@%\$]\w+)/g;
        $score{perl}+= 2                if /;\s*$/;
        $score{perl}+=10                if /(if|for|while|until|unless)\s*\(/;
        $score{perl}++                  for /([\{\}])/g;
        $score{equal}++, $score{ini}++  if m|^\s*\w+\s*=.*$|;
        $score{ini} += 10               if /^\s*\[[\s\w]+\]\s*$/;
    }

    # Choose between Win INI format and foo = bar
    if (exists $score{ini}) {
        $score{ini} > $score{equal}
            ? delete $score{equal}
            : delete $score{ini};
    }

    # Some general sanity checks
    if (exists $score{perl}) {
        $score{perl} /= 2   unless ("@$data_r" =~ /;/) > 3 or $#$data_r < 3;
        delete $score{perl} unless ("@$data_r" =~ /;/);
        delete $score{perl} unless ("@$data_r" =~ /([\$\@\%]\w+)/);
    }

    return %score;
}

sub find_file {
    my($file,$path) = @_;

    my $x;
    my $whoami = basename($0);
    my $bindir = dirname($0);

   $whoami =~ s/\.(pl|t)$//;
 
   my @filenames = $file ||
                     ("${whoami}config", "${whoami}.config", 
                      "${whoami}rc", ".${whoami}rc");


   foreach my $filename (@filenames) {
       return $filename        if -e $filename;
       return $x               if ($x = _chkpaths($path,$filename)) and -e $x;
       return $x               if -e ($x = catfile($bindir,$filename));
       return $x               if -e ($x = catfile($ENV{HOME},$filename));
       return "/etc/$filename" if -e "/etc/$filename";
       return "/usr/local/etc/$filename"  
                               if -e "/usr/local/etc/$filename";
    }
    return undef;
}

sub _chkpaths {
    my ($paths,$filename)=@_;
    my $file;

    if ($paths) {

        if(ref($paths) eq 'ARRAY') {
            foreach my $path (@$paths) {
                return $file if -e ($file = catfile($path,$filename));
            }
            
        } else {
            return $file     if -e ($file = catfile($paths,$filename));
        }
    
    } else {
        return undef;
    }
}

sub eval_perl   {
  my $file = shift;
  ($file) = $file =~ m/^(.*)$/s if $Untaint;
  my $cfg = do $file;
  croak __PACKAGE__ . " couldn't parse $file: $@" if $@;
  croak __PACKAGE__ . " couldn't do $file: $!"    unless defined $cfg;
  croak __PACKAGE__ . " couldn't run $file"       unless $cfg;
  return $cfg;
}

sub parse_xml   { return XMLin(shift); }
sub parse_ini   { tie my %ini, 'Config::IniFiles', (-file=>$_[0]); 
                    return \%ini; }
sub return_list { open my $fh, shift or die $!; return [<$fh>]; }
sub yaml        { require YAML; return YAML::LoadFile( shift ) }

sub bind_style  { croak "BIND8-style config not supported in this release" }
sub irssi_style { croak "irssi-style config not supported in this release" }

# BUG: These functions are too similar. How can they be unified?

sub colon_sep {

    my $file = shift;
    open my $in, $file or die $!;
    my %config;
    while (<$in>) {
        next if /^\s*#/;
        /^\s*(.*?)\s*:\s*(.*)/ or next;
        my ($k, $v) = ($1, $2);
        my @v;
        if ($v =~ /:/) {
            @v =  split /:/, $v;
        } elsif ($v =~ /, /) {
            @v = split /\s*,\s*/, $v;
        } elsif ($v =~ / /) {
            @v = split /\s+/, $v;
        } elsif ($v =~ /,/) { # Order is important
            @v = split /\s*,\s*/, $v;
        } else {
            @v = $v;
        }
        check_hash_and_assign(\%config, $k, @v);
    }
    return \%config;
}

sub check_hash_and_assign {
    my ($c, $k, @v) = @_;
    if (exists $c->{$k} and !ref $c->{$k}) {
        $c->{$k} = [$c->{$k}];
    }

    if (grep /=/, @v) { # Bugger, it's really a hash
        for (@v) {
            my ($subkey, $subvalue);
            if (/(.*)=(.*)/) { ($subkey, $subvalue) = ($1,$2); }
            else { $subkey = $1; $subvalue = 1; }

            if (exists $c->{$k} and ref $c->{$k} ne "HASH") {
                # Can we find a hash in here?
                my $h=undef;
                for (@{$c->{$k}}) {
                    last if ref ($h = $_) eq "hash";
                }
                if ($h) { $h->{$subkey} = $subvalue; }
                else { push @{$c->{$k}}, { $subkey => $subvalue } }
            } else {
                $c->{$k}{$subkey} = $subvalue;
            }
        }
    } elsif (@v == 1) {
        if (exists $c->{$k}) {
            if (ref $c->{$k} eq "HASH") { $c->{$k}{$v[0]} = 1; }
            else {push @{$c->{$k}}, @v}
        } else { $c->{$k} = $v[0]; }
    } else {
        if (exists $c->{$k}) {
            if (ref $c->{$k} eq "HASH") { $c->{$k}{$_} = 1 for @v }
            else {push @{$c->{$k}}, @v }
        }
        else { $c->{$k} = [@v]; }
    }
}


sub equal_sep {
    my $file = shift;
    open my $in, $file or die $!;
    my %config;
    while (<$in>) {
        next if /^\s*#/;
        /^\s*(.*?)\s*=\s*(.*)\s*$/ or next;
        my ($k, $v) = ($1, $2);
        my @v;
        if ($v=~ /,/) {
            $config{$k} = [ split /\s*,\s*/, $v ];
        } elsif ($v =~ / /) { # XXX: Foo = "Bar baz"
            $config{$k} = [ split /\s+/, $v ];
        } else {
            $config{$k} = $v;
        }
    }

    return \%config;
}

sub space_sep {
    my $file = shift;
    open my $in, $file or die $!;
    my %config;
    while (<$in>) {
        next if /^\s*#/;
        /\s*(\S+)\s+(.*)/ or next;
        my ($k, $v) = ($1, $2);
        my @v;
        if ($v=~ /,/) {
            @v = split /\s*,\s*/, $v;
        } elsif ($v =~ / /) { # XXX: Foo = "Bar baz"
            @v = split /\s+/, $v;
        } else {
            @v = $v;
        }
        check_hash_and_assign(\%config, $k, @v);
    }
    return \%config;

}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Config::Auto - Magical config file parser

=head1 SYNOPSIS

  use Config::Auto;

  # Not very magical at all.
  my $config = Config::Auto::parse("myprogram.conf", format => "colon");

  # Considerably more magical.
  my $config = Config::Auto::parse("myprogram.conf");

  # Highly magical.
  my $config = Config::Auto::parse();

=head1 DESCRIPTION

This module was written after having to write Yet Another Config File Parser
for some variety of colon-separated config. I decided "never again".

When you call C<Config::Auto::parse> with no arguments, we first look at
C<$0> to determine the program's name. Let's assume that's C<snerk>. We
look for the following files:

    snerkconfig
    ~/snerkconfig
    /etc/snerkconfig
    /usr/local/etc/snerkconfig
    snerk.config
    ~/snerk.config
    /etc/snerk.config
    /usr/local/etc/snerk.config
    snerkrc
    ~/snerkrc
    /etc/snerkrc
    /usr/local/etc/snerkrc
    .snerkrc
    ~/.snerkrc
    /etc/.snerkrc
    /usr/local/etc/.snerkrc

Additional search paths can be specified with the C<paths> option.

We take the first one we find, and examine it to determine what format
it's in. The algorithm used is a heuristic "which is a fancy way of
saying that it doesn't work." (Mark Dominus.) We know about colon
separated, space separated, equals separated, XML, Perl code, Windows
INI, BIND9 and irssi style config files. If it chooses the wrong one,
you can force it with the C<format> option.

If you don't want it ever to detect and execute config files which are made
up of Perl code, set C<$Config::Auto::DisablePerl = 1>.

When using the perl format, your configuration file will be eval'd. This will
cause taint errors. To avoid these warnings, set C<$Config::Auto::Untaint = 1>.

When using the perl format, your configuration file will be eval'd using
do(file). This will cause taint errors if the filename is not untainted. To
avoid these warnings, set C<$Config::Auto::Untaint = 1>. This setting will not
untaint the data in your configuration file and should only be used if you
trust the source of the filename.

Then the file is parsed and a data structure is returned. Since we're
working magic, we have to do the best we can under the circumstances -
"You rush a miracle man, you get rotten miracles." (Miracle Max) So
there are no guarantees about the structure that's returned. If you have
a fairly regular config file format, you'll get a regular data
structure back. If your config file is confusing, so will the return
structure be. Isn't life tragic?

Here's what we make of some common Unix config files:

F</etc/resolv.conf>:

    $VAR1 = {
          'nameserver' => [ '163.1.2.1', '129.67.1.1', '129.67.1.180' ],
          'search' => [ 'oucs.ox.ac.uk', 'ox.ac.uk' ]
        };

F</etc/passwd>:

    $VAR1 = {
          'root' => [ 'x', '0', '0', 'root', '/root', '/bin/bash' ],
          ...
        };

F</etc/gpm.conf>:

    $VAR1 = {
          'append' => '""',
          'responsiveness' => '',
          'device' => '/dev/psaux',
          'type' => 'ps2',
          'repeat_type' => 'ms3'
        };

F</etc/nsswitch.conf>:

    $VAR1 = {
          'netgroup' => 'nis',
          'passwd' => 'compat',
          'hosts' => [ 'files', 'dns' ],
          ...
    };

=head1 PARAMETERS

Although C<Config::Auto> is at its most magical when called with no parameters,
its behavior can be reined in by use of one or two arguments.

If a filename is passed as the first argument to C<parse>, the same paths are
checked, but C<Config::Auto> will look for a file with the passed name instead
of the C<$0>-based names.

 use Config::Auto;

 my $config = Config::Auto::parse("obscure.conf");

The above call will cause C<Config::Auto> to look for:

 obscure.conf
 ~/obscure.conf
 /etc/obscure.conf

Parameters after the first are named.

=head2 C<format> 

forces C<Config::Auto> to interpret the contents of the
configuration file in the given format without trying to guess.
 
=head2 C<path>

add additional directories to the search paths. The current directory
is searched first, then the paths specified with the path parameter.
C<path> can either be a scalar or a reference to an array of paths to check.

=head2 Formats

C<Config::Auto> recognizes the following formats:

=over 4

=item * perl    => perl code

=item * colon   => colon separated (e.g., key:value)

=item * space   => space separated (e.g., key value)

=item * equal   => equal separated (e.g., key=value)

=item * bind    => bind style (not available)

=item * irssi   => irssi style (not available)

=item * xml     => xml (via XML::Simple)

=item * ini     => .ini format (via Config::IniFiles)

=item * list    => list (e.g., ??)

=item * yaml    => yaml (via YAML.pm)

=back

=head1 TROUBLESHOOTING

=over 4

=item When using a Perl config file, the configuration is borked

Give C<Config::Auto> more hints (e.g., add #!/usr/bin/perl to beginning of
file) or indicate the format in the parse() command.

=back

=head1 TODO

BIND9 and irssi file format parsers currently don't exist. It would be
good to add support for C<mutt> and C<vim> style C<set>-based RCs.

=head1 BUG REPORTS

Please report bugs or other issues to E<lt>bug-config-auto@rt.cpan.orgE<gt>.

=head1 AUTHOR

This module by Jos Boumans E<lt>kane@cpan.orgE<gt>.

=head1 COPYRIGHT

This library is free software; you may redistribute and/or modify it 
under the same terms as Perl itself.

=cut
