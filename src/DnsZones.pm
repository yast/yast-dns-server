#! /usr/bin/perl -w
# File:         modules/DnsZones.pm
# Package:      Configuration of DNS Server
# Summary:      Input and output functions for DNS zones
# Authors:      Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
# Contains routines for handling zone files (both directly and using nsupdate)

package DnsZones;

use strict;

use ycp;
use YaST::YCP qw(Boolean);
use Data::Dumper;
use Time::localtime;

use Locale::gettext;
use POSIX ();     # Needed for setlocale()

POSIX::setlocale(LC_MESSAGES, "");
textdomain("dns-server");

#use io_routines;
#use check_routines;

our %TYPEINFO;

# FIXME this should be defined only once for all modules
#sub _ {
#    return gettext ($_[0]);
#}


YaST::YCP::Import ("SCR");
use DnsTsigKeys;

##-------------------------------------------------------------------------
##----------------- various routines --------------------------------------

BEGIN{$TYPEINFO{GetFQDN} = ["function", "string"];}
sub GetFQDN {
    my $self = shift;

    my $out = SCR->Execute (".target.bash_output", "/bin/hostname --fqdn");
    if ($out->{"exit"} ne 0)
    {
	return "@";
    }
    my $stdout = $out->{"stdout"};
    my ($ret, $rest) = split ("\n", $stdout, 2);
    return $ret;
}

BEGIN { $TYPEINFO{AbsoluteZoneFileName} = ["function", "string", "string" ]; }
sub AbsoluteZoneFileName {
    my $self = shift;
    my $file_name = shift;

    if (substr ($file_name, 0, 1) eq "/")
    {
	return $file_name;
    }
    return "/var/lib/named/$file_name";
}

BEGIN{$TYPEINFO{UpdateSerial} = ["function", "string", "string"];}
sub UpdateSerial {
    my $self = shift;
    my $serial = shift;

    if (! defined ($serial))
    {
	$serial = "0000000000";
    }

    my $year = 1900 + localtime->year();
    my $month = 1 + localtime->mon();
    my $day = localtime->mday();

    while (length ($month) < 2)
    {
	$month = "0$month";
    }
    while (length ($day) < 2)
    {
	$day = "0$day";
    }
    while (length ($year) > 4)
    {
	$year = substr ($year, 1);
    }
    my $date = "$year$month$day";
    my $suffix = "00";
    if (substr ($serial, 0, 8) eq $date)
    {
	$suffix = substr ($serial, 8, 2);
	$suffix = $suffix + 1;
	while (length ($suffix) < 2)
	{
	    $suffix = "0$suffix";
	}
	while (length ($suffix) > 2)
	{
	    $suffix = substr ($suffix, 1);
	}
    }
    $serial = "$date$suffix";
    y2milestone ("New serial $serial");
    $serial;
}

BEGIN{$TYPEINFO{GetDefaultSOA} = ["function", ["map", "string", "string"]];}
sub GetDefaultSOA {
    my $self = shift;

    my $fqdn = $self->GetFQDN ();
    $fqdn = "$fqdn.";
    my $adm_mail = "root.$fqdn";
    my %soa = (
	"expiry" => "1W",
	"mail" => $adm_mail,
	"minimum" => "1D",
	"refresh" => "3H",
	"retry" => "1H",
	"server" => $fqdn,
	"zone" => "@",
	"serial" => $self->UpdateSerial (""),
    );
    return \%soa;
}

BEGIN{$TYPEINFO{UpdateSOA} = ["function", "boolean", ["map", "any", "any"]];}
sub UpdateSOA {
    my $self = shift;
    my $zonemap_ref = shift;

    my $ttl = $zonemap_ref->{"ttl"};
    my $filename = $zonemap_ref->{"file"} || "";
    my $soa_ref = $zonemap_ref->{"soa"};
    y2milestone ("Updating SOA of $filename");

    $filename = $self->AbsoluteZoneFileName ($filename);
    my $rz_ref = SCR->Read (".dns.zone", "$filename");
    if (! defined ($rz_ref))
    {
	# new zone file
	$rz_ref = {
	    "soa" => $self->GetDefaultSOA (),
	    "TTL" => "2D",
	};
    }
    my %soa = %{$rz_ref->{"soa"} || {}};

    $rz_ref->{"TTL"} = $ttl if (defined ($ttl));
    $rz_ref->{"soa"} = $soa_ref if (defined ($soa_ref));

    return SCR->Write (".dns.zone", [$filename, $rz_ref]);
}

BEGIN { $TYPEINFO{ZoneRead} = ["function", [ "map", "any", "any" ], "string", "string" ]; }
sub ZoneRead {
    my $self = shift;
    my $zone = shift;
    my $file = shift;

    my $zonemap_ref = SCR->Read (".dns.zone", "/var/lib/named/$file");
    if (! defined ($zonemap_ref))
    {
	return return {};
    }
    my %zonemap = %{$zonemap_ref};
    my %soa = %{$zonemap{"soa"} || {}};
    my %ret = (
	"zone" => $zone,
	"ttl" => $zonemap{"TTL"} || "2D",
	"soa" => \%soa,
    );
    my @original_records = @{$zonemap{"records"} || []};
    my %in_mx = ();
    my %in_prt = ();
    my %in_cname = ();
    my %in_a = ();
    my $previous_key = "$zone.";

    my @records = ();
    foreach my $r (@original_records) {
	my %r = %{$r};
	my $key = $r{"key"} || "";
	my $type = $r{"type"} || "";
	my $value = $r{"value"} || "";

	if ($key eq "")
	{
	    $key = $previous_key;
	}
	else
	{
	    $previous_key = $key;
	}
	push @records, {
	    "key" => $key,
	    "type" => $type,
	    "value" => $value,
	};
    }

    $ret{"records"} = \@records;

    return \%ret;
}

BEGIN { $TYPEINFO{ZoneFileWrite} = ["function", "boolean", [ "map", "any", "any"]];}
sub ZoneFileWrite {
    my $self = shift;
    my %zone_map = %{+shift};

    my $zone_file = $zone_map{"file"} || "";
    $zone_file = $self->AbsoluteZoneFileName ($zone_file);
    my $zone_name = $zone_map{"zone"} || "@";
    my $ttl = $zone_map{"ttl"} || "2D";

    my %soa = %{$self->GetDefaultSOA ()};
    my %current_soa = %{$zone_map{"soa"}};
    while ((my $key, my $value) = each %current_soa)
    {
	$soa{$key} = $value;
    }

    my @records = @{$zone_map{"records"} || []};

    my %save = (
	"TTL" => $ttl,
	"soa" => \%soa,
	"records" => \@records,
    );
    return SCR->Write (".dns.zone", [$zone_file, \%save]);
}

BEGIN{$TYPEINFO{UpdateZones}=["function",["list",["map","any","any"]]];}
sub UpdateZones {
    my $self = shift;
    my @zone_descr = @{+shift};

    y2milestone ("Updaging zones");
    my $ok = 1;
    foreach my $zone_descr (@zone_descr) {
	my $zone_name = $zone_descr->{"zone"};
	my $actions_ref = $zone_descr->{"actions"};
	my @actions = @{$actions_ref};
	my $tsig_key = $zone_descr->{"tsig_key"};
	my $ttl = $zone_descr->{"ttl"} || "";
	my $tsig_key_value = DnsTsigKeys->TSIGKeyName2TSIGKey ($tsig_key);

	my @commands = (
	    "server 127.0.0.1",
	    "key $tsig_key $tsig_key_value",
	);
	my @uc = map {
	    my $a = $_;
	    my $operation = $a->{"operation"};
	    my $type = $a->{"type"};
	    my $key = $a->{"key"};
	    my $value = $a->{"value"};
	    if ($operation ne "add")
	    {
		$ttl = "";
	    }
	    if (substr ($key, length ($key) -1, 1) ne ".")
	    {
		$key = "$key.$zone_name";
	    }
	    if (substr ($key, length ($key) -1, 1) ne ".")
	    {
		$key = "$key.";
	    }
	    "update $operation $key $ttl $type $value";
	} @actions;
	push @commands, @uc;
	push @commands, "";
	push @commands, "";
	my $command = join ("\n", @commands);
	y2milestone ("Running command $command");
	my $xx = SCR->Execute (".target.bash_output",
	    "echo '$command' | /usr/bin/nsupdate");
    }
    return $ok;
}


# EOF
