#! /usr/bin/perl -w
#
# DnsServer module written in Perl
#

package DnsServer;

use strict;

use ycp;
use YaST::YCP qw(Boolean);
use Data::Dumper;
use Time::localtime;

#use io_routines;
#use check_routines;

our %TYPEINFO;

# persistent variables

my $start_service = 0;

my $chroot = 0;

my @allowed_interfaces = ();

my @zones = ();

my %options = ();

my %logging = ();

#transient variables

my $modified = 0;

my $save_all = 0;

my @files_to_delete = ();

my %current_zone = ();

my $current_zone_index = -1;

my $adapt_firewall = 0;

my %firewall_settings = ();

my $write_only = 0;


# FIXME remove this func

sub _ {
    return $_[0];
}


YaST::YCP::Import ("SCR");
YaST::YCP::Import ("Mode");
YaST::YCP::Import ("Service");

##-------------------------------------------------------------------------
##----------------- various routines --------------------------------------

BEGIN { $TYPEINFO{AbsoluteZoneFileName} = ["function", "string", "string" ]; }
sub AbsoluteZoneFileName {
    my $file_name = $_[0];

    if (substr ($file_name, 0, 1) eq "/")
    {
	return $file_name;
    }
    return "/var/lib/named/$file_name";
}

sub UpdateSerial {
    my $serial = $_[0];

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

sub contains {
    my @list = @{$_[0]};
    my $value = $_[1];

    my $found = 0;
    foreach my $x (@list) {
	if ($x eq $value)
	{
	    $found = 1;
	    last;
	}
    }
    $found;
}

##------------------------------------
# Routines for reading/writing configuration

BEGIN { $TYPEINFO{ZoneRead} = ["function", [ "map", "any", "any" ], "string", "string" ]; }
sub ZoneRead {
    my $zone = $_[0];
    my $file = $_[1];

    my %zonemap = %{SCR::Read (".dns.zone", "/var/lib/named/$file")};
    my %soa = %{$zonemap{"soa"} || {}};
    $soa{"serial"} = UpdateSerial ($soa{"serial"} || "");
    my %ret = (
	"zone" => $zone,
	"ttl" => $zonemap{"TTL"} || "2W",
	"soa" => \%soa,
    );
    my @original_records = @{$zonemap{"records"}};
    my %in_mx = ();
    my %in_prt = ();
    my %in_cname = ();
    my %in_a = ();
    my $previous_key = "$zone.";

    my %records = ();
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
	my %host = %{$records{$key} || {}};
	my @items = @{$host{$type} || []};
	push (@items, $value);
	$host{$type} = \@items;
	$records{$key} = \%host;
    }

    $ret{"records"} = \%records;

    return %ret;
}

BEGIN { $TYPEINFO{ZoneFileUpdate} = ["function", "boolean", [ "map", "any", "any" ]];}
sub ZoneFileUpdate {
    my %zone_map = %{$_[0]};
    my @actions = @{$zone_map{"update_actions"}};
    foreach my $action (@actions) {
	
	# TODO perform the action
    }
}

BEGIN { $TYPEINFO{ZoneFileWrite} = ["function", "boolean", [ "map", "any", "any"]];}
sub ZoneFileWrite {
    my %zone_map = %{$_[0]};

    my $zone_file = $zone_map{"file"} || "";
    $zone_file = AbsoluteZoneFileName ($zone_file);
    my $zone_name = $zone_map{"zone"} || "@";
    my $ttl = $zone_map{"ttl"} || "2W";

    my %soa = (
	"zone" => "@",
	"expiry" => "6W",
	"mail" => "root",
	"minimum" => "1W",
	"refresh" => "2D",
	"retry" => "4H",
	"server" => "@",
    );
    my %current_soa = %{$zone_map{"soa"}};
    while ((my $key, my $value) = each %current_soa)
    {
	$soa{$key} = $value;
    }

    my @records = ();

    my %records = %{$zone_map{"records"} || {}};
    while ((my $key, my $values_ref) = each (%records)) {
	my %values = %{$values_ref};
	my @types = keys (%values);
	my @preferred = ("A", "CNAME", "PTR");
	@preferred = grep {
	    contains ( \@preferred, $_);
	} @types;
	my @others = grep {
	    ! contains (\@preferred, $_);
	} @types;
	@types = ( @preferred, @others );
	foreach my $type (@types) {
	    my $res_rec_ref = $values{$type};
	    my @res_rec = @{$res_rec_ref};
	    foreach my $rr (@res_rec) {
		my %new_rec = (
		    "key" => $key,
		    "type" => $type,
		    "value" => $rr,
		);
		push (@records, \%new_rec);
	    }
	}
    }

    my %save = (
	"TTL" => $ttl,
	"soa" => \%soa,
	"records" => \@records,
    );
    return SCR::Write (".dns.zone", [$zone_file, \%save]);
}

BEGIN { $TYPEINFO{ZoneWrite} = ["function", "boolean", [ "map", "any", "any" ] ]; }
sub ZoneWrite {
    my %zone_map = %{$_[0]};

    if (! ($zone_map{"modified"} || $save_all))
    {
	return 1;
    }

    my $zone_name = $zone_map{"zone"} || "";
    if ($zone_name eq "")
    {
	return 0;
    }

    my $zone_file = $zone_map{"file"} || "";
    if ($zone_file eq "")
    {
	$zone_file = "master/$zone_name";
	$zone_map{"file"} = $zone_file;
    }

    #save changed of named.conf
    my $base_path = ".dns.named.value.\"zone \\\"$zone_name\\\" in\"";
    SCR::Write (".dns.named.section.\"zone \\\"$zone_name\\\" in\"", "");

    my @old_options = SCR::Dir ($base_path) || ();
    my @save_options = @old_options;

    my $zone_type = $zone_map{"type"} || "master";

    if ($zone_type eq "master")
    {
	# write the zone file
	if (! $zone_map{"soa_modified"})
	{
	    ZoneFileWrite (\%zone_map);
	}
	else
	{
	    ZoneFileUpdate (\%zone_map);
	}
	@save_options = ("type", "file");

	# write existing keys
	SCR::Write ("$base_path.$zone_file", "\"$zone_file\"");
    }
    elsif ($zone_type eq "slave" || $zone_type eq "stub")
    {
	@save_options = ("masters");
	my $masters = $zone_map{"masters"} || "";
	if (! $masters =~ /\{.*;\}/)
	{
	    $zone_map{"masters"} = "{$masters;}";
	}
        SCR::Write ("$base_path.masters", $zone_map{"masters"} || "");
    }
    elsif ($zone_type eq "hint")
    {
	@save_options = ("type", "file");
	SCR::Write ("$base_path.file", "\"$zone_file\"");
    }

    my @del_options = grep {
	! contains (\@save_options, $_);
    } @old_options;
    foreach my $o (@del_options) {
	SCR::Write ("$base_path.$o", undef);
    };
    SCR::Write ("$base_path.type", $zone_map{"type"} || "master");

    return 1;
}

BEGIN { $TYPEINFO{AdaptFirewall} = ["function", "boolean"]; }
sub AdaptFirewall {
    if (! $adapt_firewall)
    {
	return 1;
    }

    SCR::Write (".sysconfig.SuSEfirewall2.FW_SERVICE_DNS", $start_service
	? "yes"
	: "no");

# TODO enable or disable firewall for particular interfaces

    SCR::Write (".sysconfig.SuSEfirewall2", undef);
    if (! $write_only)
    {
	SCR::Execute (".target.bash", "test -x /sbin/rcSuSEfirewall2 && /sbin/rcSuSEfirewall2 status && /sbin/rcSuSEfirewall2 restart");
    }
}

BEGIN { $TYPEINFO{SaveGlobals} = [ "function", "boolean" ]; }
sub SaveGlobals {

    #delete all deleted zones first
    my @old_sections = SCR::Dir (".dns.named.section") || ();
    my @old_zones = grep (/^zone/, @old_sections);
    my @current_zones = map {
	my %zone = %{$_};
	"zone \"$zone{\"zone\"}\" in";
    } @zones;
    my @del_zones = grep {
	! contains (\@zones, $_);
    } @old_zones;
    y2milestone ("Deleting zones @del_zones");
    foreach my $z (@del_zones) {
	SCR::Write (".dns.named.section.$z", undef);
    }

    # delete all removed options
    my @old_options = SCR::Dir (".dns.named.value.options") || ();
    my @current_options = keys (%options);
    my @del_options = grep {
	! contains (\@current_options, $_);
    } @old_options;
    foreach my $o (@del_options) {
	SCR::Write (".dns.named.value.options.$o", undef);
    }

    # save the settings
    while ((my $key, my $value) = each %options)
    {
	SCR::Write (".dns.named.value.options.$key", $value);
    }

    # really save the file
    return SCR::Write (".dns.named", undef);
}



##------------------------------------
# Store/Find/Select/Remove a zone

BEGIN { $TYPEINFO{StoreZone} = ["function", "boolean"]; }
sub StoreZone {
    $current_zone{"modified"} = 1;
    if ($current_zone_index == -1)
    {
	push (@zones, \%current_zone);
    }
    else
    {
	$zones[$current_zone_index] = \%current_zone;
    }
}

BEGIN { $TYPEINFO{FindZone} = ["function", "integer", "string"]; }
sub FindZone {
    my $zone_name = $_[0];

    my $found_index = -1;
    my $index = -1;

    map {
	$index = $index + 1;
	my %zone_map = %{$_};
	if ($zone_map{"zone"} eq $zone_name)
	{
	    $found_index = $index;
	}
    } @zones;
    return $found_index;
}

BEGIN { $TYPEINFO{RemoveZone} = ["function", "boolean", "string", "boolean"]; }
sub RemoveZone {
    my $zone_name = $_[0];
    my $delete_file = $_[1];

    my $zone_index = FindZone ($zone_name);
    if ($zone_index == -1)
    {
	y2error ("Zone $zone_name not found");
	return 0;
    }

    if ($delete_file)
    {
	my %zone_map = %{$zones[$zone_index]};
	my $filename = AbsoluteZoneFileName ($zone_map{"file"});
	push (@files_to_delete, $filename) if (defined ($filename));
    }

    $zones[$zone_index] = 0;

    @zones = grep {
	ref ($_);
    } @zones;
    return 1;
}

BEGIN { $TYPEINFO{SelectZone} = ["function", "boolean", "integer"]; }
sub SelectZone {
    my $zone_index = $_[0];

    my $ret = 1;

    if ($zone_index < -1)
    {
	y2error ("Zone with index $zone_index doesn't exist");
	$zone_index = -1;
	$ret = 0;
    }
    elsif ($zone_index >= @zones)
    {
	y2error ("Zone with index $zone_index doesn't exist");
	$zone_index = -1;
	$ret = 0;
    }

    if ($zone_index == -1)
    {
	my $serial =  UpdateSerial ("");
	my %new_soa = (
	    "expiry" => "6W",
	    "mail" => "root",
	    "minimum" => "1W",
	    "refresh" => "2D",
	    "retry" => "4H",
	    "serial" => $serial,
	    "server" => "@",
	    "zone" => "@",
	);
	%current_zone = (
	    "soa_modified" => 1,
	    "modified" => 1,
	    "type" => "master",
	    "soa" => \%new_soa,
	    "ttl" => "2W",
	);
    }
    else
    {
	%current_zone = %{$zones[$zone_index]};
    }

    return $ret;
}

##------------------------------------
# Functions for accessing the data

BEGIN { $TYPEINFO{SetStartService} = [ "function", "void", "boolean" ];}
sub SetStartService {
    $start_service = $_[0];
    SetModified ();
}

BEGIN { $TYPEINFO{GetStartService} = [ "function", "boolean" ];}
sub GetStartService {
    return $start_service;
}

BEGIN { $TYPEINFO{SetModified} = ["function", "void" ]; }
sub SetModified {
    $modified = 1;
}

BEGIN { $TYPEINFO{WasModified} = ["function", "boolean" ]; }
sub WasModified {
    return $modified;
}

BEGIN { $TYPEINFO{SetWriteOnly} = ["function", "void", "boolean" ]; }
sub SetWriteOnly {
    $write_only = $_[0];
}

BEGIN { $TYPEINFO{SetAdaptFirewall} = ["function", "void", "boolean" ]; }
sub SetAdaptFirewall {
    $adapt_firewall = $_[0];
}

BEGIN { $TYPEINFO{GetAdaptFirewall} = [ "function", "boolean" ];}
sub GetAdaptFirewall {
    return $adapt_firewall;
}

BEGIN {$TYPEINFO{FetchCurrentZone} = [ "function", ["map", "any", "any"] ]; }
sub FetchCurrentZone {
    return \%current_zone;
}

BEGIN {$TYPEINFO{StoreCurrentZone} = [ "function", "boolean", ["map", "any", "any"] ]; }
sub StoreCurrentZone {
    %current_zone = %{$_[0]};
    return 1;
}

BEGIN {$TYPEINFO{FetchZones} = [ "function", ["list", ["map", "any", "any"] ] ]; }
sub FetchZones {
    return \@zones;
}

BEGIN {$TYPEINFO{StoreZones} = [ "function", "void", [ "list", ["map", "any", "any"] ] ]; }
sub StoreZones {
    @zones = @{$_[0]};
}

BEGIN {$TYPEINFO{GetGlobalOptions} = [ "function", ["map", "any", "any"] ]; }
sub GetGlobalOptions {
    return \%options;
}

BEGIN {$TYPEINFO{SetGlobalOptions} = [ "function", "void", [ "map", "any", "any" ] ]; }
sub SetGlobalOptions {
    %options = ${$_[0]};
}

BEGIN {$TYPEINFO{GetGlobalOption} = [ "function", "any", "any" ];}
sub GetGlobalOption {
    my $key = $_[0];

    return $options{$key};
}

BEGIN {$TYPEINFO{SetGlobalOption} = ["function", "void", "any", "any"];}
sub SetGlobalOption {
    my $key = $_[0];
    my $value = $_[1];

    $options{$key} = $value;
}

BEGIN {$TYPEINFO{RemoveGlobalOption} = ["function", "void", "any" ];}
sub RemoveGlobalOption {
    my $key = $_[0];

    delete ($options{$key});
}

##------------------------------------
BEGIN { $TYPEINFO{Read} = ["function", "boolean"]; }
sub Read {
# Check packages
# TODO

# Information about the daemon

    $start_service = Service::Enabled ("named");
    y2milestone ("Service start: $start_service");
    $chroot = SCR::Read (".sysconfig.named.NAMED_RUN_CHROOTED", "")
	? 1
	: 0;
    y2milestone ("Chroot: $chroot");

    my @zone_headers = SCR::Dir (".dns.named.section");
    @zone_headers = grep (/^zone/, @zone_headers);
    y2milestone ("Read zone headers @zone_headers");

    my @opt_names = SCR::Dir (".dns.named.value.options");
    if (! @opt_names)
    {
	@opt_names = ();
    }
    foreach my $key (@opt_names) {
	$options{$key} = SCR::Read (".dns.named.value.options.$key");
    }
    foreach my $key (keys(%options)) {
    }

    @zones = map {
	my $zonename = $_;
	$zonename =~ s/.*\"(.*)\".*/$1/;
	my $path_el = $_;
	$path_el =~ s/\"/\\\"/g;
	$path_el = "\"$path_el\"";
	my $zonetype = SCR::Read (".dns.named.value.$path_el.type");
	my $filename = SCR::Read (".dns.named.value.$path_el.file");
	if ($filename =~ /^\".*\"$/)
	{
	    $filename =~ s/^\"(.*)\"$/$1/;
	}
	my %zd = ();
	if ($zonetype eq "master")
	{
	    %zd = ZoneRead ($zonename, $filename);
	}
	elsif ($zonetype eq "slave" || $zonetype eq "stub")
	{
	    $zd{"masters"} = SCR::Read (".dns.named.value.$_.masters");
	    if ($zd{"masters"} =~ /\{.*;\}/)
	    {
		$zd{"masters"} =~ s/\{(.*);\}/$1/
	    }
	}
	else
	{
# TODO hint, forward, .... not supported at the moment
	}
	$zd{"file"} = $filename;
	$zd{"type"} = $zonetype;
	$zd{"zone"} = $zonename;
	\%zd;
    } @zone_headers;
    $modified = 0;
    return "true";
}

BEGIN { $TYPEINFO{Write} = ["function", "boolean"]; }
sub Write {
    my $ok = 1;

    if (! $modified)
    {
	return "true";
    }

    #adapt firewall
    $ok = AdaptFirewall () && $ok;

    #save globals
    $ok = SaveGlobals () && $ok;

    #save all zones
    foreach my $z (@zones) {
	$ok = ZoneWrite ($z) && $ok;
    }

    #be sure the named.conf file is saved
    SCR::Write (".dns.named", undef);
    
    #set daemon starting
    SCR::Write (".sysconfig.named.NAMED_RUN_CHROOTED", $chroot ? "yes" : "no");
    SCR::Write (".sysconfig.named", undef);

    if ($start_service)
    {
	my $ret = 0;
	if (! $write_only)
	{
	    $ret = SCR::Execute (".target.bash", "/etc/init.d/named restart");
	}
	Service::Enable ("named");
	if (0 != $ret)
	{
	    $ok = 0;
	}
    }
    else
    {
	if (! $write_only)
	{
	    SCR::Execute (".target.bash", "/etc/init.d/named stop");
	}
	Service::Disable ("named");
    }

    return $ok;
}

BEGIN { $TYPEINFO{Export}  =["function", [ "map", "any", "any" ] ]; }
sub Export {
    my %ret = (
	"start_service" => $start_service,
	"chroot" => $chroot,
	"allowed_interfaces" => \@allowed_interfaces,
	"zones" => \@zones,
	"options" => \%options,
	"logging" => \%logging,
    );
    return \%ret;
}
BEGIN { $TYPEINFO{Import} = ["function", "void", [ "map", "any", "any" ] ]; }
sub Import {
    my %settings = %{$_[0]};

    $start_service = $settings{"start_service"} || 0;
    $chroot = $settings{"chroot"} || 1;
    @allowed_interfaces = @{$settings{"allowed_interfaces"} || []};
    @zones = @{$settings{"zones"} || []}; 
    %options = %{$settings{"options"} || {}};
    %logging = %{$settings{"logging"} || {}};

    $modified = 1;
    $save_all = 1;
    @files_to_delete = ();
    %current_zone = ();
    $current_zone_index = -1;
    $adapt_firewall = 0;
    $write_only = 0;
}

BEGIN { $TYPEINFO{Summary} = ["function", [ "list", "string" ] ]; }
sub Summary {
    my %zone_types = (
	# type of zone to be used in summary
	"master" => _("master"),
	# type of zone to be used in summary
	"slave" => _("slave"),
	# type of zone to be used in summary
	"stub" => _("stub"),
	# type of zone to be used in summary
	"hint" => _("hint"),
	# type of zone to be used in summary
	"forward" => _("forward"),
    );
    my @ret = ();

    if ($start_service)
    {
	# summary string
	push (@ret, _("The DNS server starts when booting the system."));
    }
    else
    {
	push (@ret,
	    # summary string
	    _("The DNS server does not start when booting the system."));
    }

    my @zones_descr = map {
	my $zone_ref = $_;
	my %zone_map = %{$zone_ref};	
	my $zone_name = $zone_map{"zone"} || "";
	my $zone_type = $zone_map{"type"} || "";
	$zone_type = $zone_types{$zone_type} || $zone_type;
	my $descr = "";
	if ($zone_name ne "")
	{
	    if ($zone_type ne "")
	    {
		$descr = "$zone_name ($zone_type)";
	    }
	    else
	    {
		$descr = "$zone_name";
	    }
	}
	$descr;
    } @zones;
    @zones_descr = grep {
	$_ ne "";
    } @zones_descr;

    my $zones_list = join (", ", @zones_descr);
    #  summary string, $zones_list is list of DNS zones (their names)
    push (@ret, _("Configured Zones: $zones_list"));
    return @ret;
}


# EOF
