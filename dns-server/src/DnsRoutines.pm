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

BEGIN{$TYPEINFO{CheckQuoting} = ["function", "boolean", "any"];}
sub CheckQuoting {
    my $class = shift;
    my $string = shift;

    # allowed quotes are only " (double quotes)

    $string =~ s/\\\"//g;
    $string =~ s/^ *\"/\"/;
    $string =~ s/\" *$/\"/;

    # starting and finishing quotes present, another inside
    if (($string =~ /^\"/) && ($string =~ /\"$/) && ($string =~ /.\"./)) {
	return 0;
    # starting quote present, finishing is not
    } elsif (($string =~ /^\"/) && ($string !~ /\"$/)) {
	return 0;
    # starting quote is not present, finishing is
    } elsif (($string !~ /^\"/) && ($string =~ /\"$/)) {
	return 0;
    }

    return 1;
}

BEGIN{$TYPEINFO{CheckBrackets} = ["function", "boolean", "any"];}
sub CheckBrackets {
    my $class = shift;
    my $string = shift;

    # allowed brackets are only {}

    $string =~ s/\\\{//g;
    $string =~ s/\\\}//g;
    $string =~ s/^ *\{/\{/;
    $string =~ s/\} *$/\}/;

    # starting and finishing brackets present, another inside
    if (($string =~ /^\{/) && ($string =~ /\}$/) && ($string =~ /.(\{|\})./)) {
	return 0;
    # starting bracket present, finishing is not
    } elsif (($string =~ /^\{/) && ($string !~ /\}$/)) {
	return 0;
    # starting bracket is not present, finishing is
    } elsif (($string !~ /^\{/) && ($string =~ /\}$/)) {
	return 0;
    }

    return 1;
}

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

    my $converted_time = 0;
    while ($time =~ s/^([0-9]+)([A-Za-z])//)
    {
	my $count = $1;
	my $unit = uc ($2);
	if ($unit eq "M")
	{
	    $converted_time += $count * 60;
	}
	elsif ($unit eq "H")
	{
	    $converted_time += $count * 60 * 60;
	}
	elsif ($unit eq "D")
	{
	    $converted_time += $count * 60 * 60 * 24;
	}
	elsif ($unit eq "W")
	{
	    $converted_time += $count * 60 * 60 * 24 * 7;
	}
	else # seconds S
	{
	    $converted_time += $count;
	}
    }

    if ($time =~ /^[0-9]+$/)
    {
	$converted_time += $time;
    }

    return $converted_time;
}


1;

# EOF
