#! /usr/bin/perl -w
#
# DnsServer module written in Perl
#

package DnsRoutines;

use strict;

use ycp;
use YaST::YCP qw(Boolean);

use YaPI;
textdomain("dns-server");

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(&NormalizeFilename);

our %TYPEINFO;

BEGIN{$TYPEINFO{NormalizeFilename} = ["function", "string", "string"];}
sub NormalizeFilename {
    my $self = shift;
    my $filename = shift;

    while ($filename ne "" && (substr ($filename, 0, 1) eq " "
	|| substr ($filename, 0, 1) eq "\""))
    {
	$filename = substr ($filename, 1);
    }
    while ($filename ne ""
	&& (substr ($filename, length ($filename) - 1, 1) eq " "
	    || substr ($filename, length ($filename) - 1, 1) eq "\""))
    {
	$filename = substr ($filename, 0, length ($filename) - 1);
    }
    return $filename;
}

BEGIN{$TYPEINFO{NormalizeTime} = ["function", "string", "string"];}
sub NormalizeTime {
    my $self = shift;
    my $time = shift;

    if ($time =~ /^([0-9]+)([A-Za-z])$/)
    {
	my $count = $1;
	my $unit = uc ($2);
	if ($unit eq "M")
	{
	    return $count * 60;
	}
	elsif ($unit eq "H")
	{
	    return $count * 60 * 60;
	}
	elsif ($unit eq "D")
	{
	    return $count * 60 * 60 * 12;
	}
	elsif ($unit eq "W")
	{
	    return $count * 60 * 60 * 12 * 7;
	}
    }
    return $time;
}


1;

# EOF
