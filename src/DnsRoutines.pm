#! /usr/bin/perl -w
#
# DnsServer module written in Perl
#

package DnsRoutines;

use strict;

use ycp;
use YaST::YCP qw(Boolean);

use Locale::gettext;
use POSIX ();     # Needed for setlocale()

POSIX::setlocale(LC_MESSAGES, "");
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


1;

# EOF
