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

use Locale::gettext;
use POSIX ();     # Needed for setlocale()

POSIX::setlocale(LC_MESSAGES, "");
textdomain("dns-server");

#use io_routines;
#use check_routines;

our %TYPEINFO;

# persistent variables

my $start_service = 0;

my $chroot = 0;

my @allowed_interfaces = ();

my @zones = ();

my @options = ();

my @logging = ();

my $ddns_file_name = "";

my @update_keys = ();

#transient variables

my $modified = 0;

my $save_all = 0;

my @files_to_delete = ();

my %current_zone = ();

my $current_zone_index = -1;

my $adapt_firewall = 0;

my %firewall_settings = ();

my $write_only = 0;

my @new_includes = ();

my @deleted_includes = ();

my @zones_update_actions = ();



# FIXME this should be defined only once for all modules
sub _ {
    return gettext ($_[0]);
}


YaST::YCP::Import ("SCR");
YaST::YCP::Import ("Mode");
YaST::YCP::Import ("Progress");
YaST::YCP::Import ("Require");
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
# FIXME this must be called somewhere else
#    $soa{"serial"} = UpdateSerial ($soa{"serial"} || "");
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

    return %ret;
}

sub TSIGKeyName2TSIGKey {
    my $key_name = shift;

    my $filename = "";
    foreach my $key (@update_keys) {
	if ($key->{"key"} eq $key_name)
	{
	    $filename = $key->{"filename"};
	}
    }
    if ($filename eq "")
    {
	y2error ("File with TSIG key not found");
	return "" ;
    }

    my $contents = SCR::Read (".target.string", $filename);
    if ($contents =~ /secret[ \t\n]+\"([^\"]+)\"/)
    {
	return $1;
    }
    y2error ("TSIG key not found in $filename");
    return "";
}

BEGIN{$TYPEINFO{UpdateZones}=["function",["list",["map","any","any"]]];}
sub UpdateZones {
    y2milestone ("Updaging zones");
    my @zone_descr = @{$_[0]};

    my $ok = 1;
    foreach my $zone_descr (@zone_descr) {
	print Dumper ($zone_descr);

	my $zone_name = $zone_descr->{"zone"};
	my $actions_ref = $zone_descr->{"actions"};
	my @actions = @{$actions_ref};
	my $tsig_key = $zone_descr->{"tsig_key"};
	my $tsig_key_value = TSIGKeyName2TSIGKey ($tsig_key);

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
	    my $ttl = "";
	    $ttl = 86400 if $operation eq "add";
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
	my $command = join ("\n", @commands);

	my $tmp_dir = SCR::Read (".target.tmpdir");
	my $tmp_file = "$tmp_dir/dns_upd";
print Dumper ($command);
	SCR::Write (".target.string", $tmp_file, $command);
	my $xx = SCR::Execute (".target.bash_output",
	    "/usr/bin/nsupdate <$tmp_file");
	print Dumper ($xx);
	# TODO perform the action

    }
    return $ok;
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
	"serial" => UpdateSerial (""),
    );
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
    return SCR::Write (".dns.zone", [$zone_file, \%save]);
}

BEGIN { $TYPEINFO{ZoneWrite} = ["function", "boolean", [ "map", "any", "any" ] ]; }
sub ZoneWrite {
    my %zone_map = %{$_[0]};

    my $zone_name = $zone_map{"zone"} || "";
    if ($zone_name eq "")
    {
	y2error ("Trying to save unnamed zone, aborting");
	return 0;
    }

    if (! ($zone_map{"modified"} || $save_all))
    {
	y2milestone ("Skipping zone $zone_name, wasn't modified");
	return 1;
    }

    my $zone_file = $zone_map{"file"} || "";
    if ($zone_file eq "")
    {
	$zone_file = "master/$zone_name";
	$zone_map{"file"} = $zone_file;
    }

    #save changed of named.conf
    my $base_path = ".dns.named.value.\"zone \\\"$zone_name\\\" in\"";
#    SCR::Write (".dns.named.section.\"zone \\\"$zone_name\\\" in\"", "");

    my @old_options = @{SCR::Dir ($base_path) || []};
    my @save_options = map {
	$_->{"key"};
    } @{$zone_map{"options"}};
    my @del_options = grep {
	! contains (\@save_options, $_);
    } @old_options;
    foreach my $o (@del_options) {
	SCR::Write ("$base_path.$o", undef);
    };

    my @tsig_keys = ();

    foreach my $o (@{$zone_map{"options"}}) {
	my $key = $o->{"key"};
	my $val = $o->{"value"};
	SCR::Write ("$base_path.$key", [$val]);
	if ($key eq "allow-update"
	    && $val =~ /^.*key[ \t]+([^ \t;]+)[ \t;]+.*$/)
	{
	    push @tsig_keys, $1;
	}
    };

    my $zone_type = $zone_map{"type"} || "master";

    if ($zone_type eq "master")
    {
	# write the zone file
	if ($zone_map{"soa_modified"} || @tsig_keys == 0)
	{
	    ZoneFileWrite (\%zone_map);
	}
	else
	{
	    my %um = (
		"actions" => $zone_map{"update_actions"},
		"zone" => $zone_name,
		"tsig_key" => $tsig_keys[0],
	    );
	    push @zones_update_actions, \%um;
	}

	# write existing keys
	SCR::Write ("$base_path.file", ["\"$zone_file\""]);
    }
    elsif ($zone_type eq "slave" || $zone_type eq "stub")
    {
	my $masters = $zone_map{"masters"} || "";
	if (! $masters =~ /\{.*;\}/)
	{
	    $zone_map{"masters"} = "{$masters;}";
	}
        SCR::Write ("$base_path.masters", [$zone_map{"masters"} || ""]);
    }
    elsif ($zone_type eq "hint")
    {
	SCR::Write ("$base_path.file", ["\"$zone_file\""]);
    }

    SCR::Write ("$base_path.type", [$zone_map{"type"} || "master"]);

    return 1;
}

BEGIN { $TYPEINFO{AdaptFirewall} = ["function", "boolean"]; }
sub AdaptFirewall {
    if (! $adapt_firewall)
    {
	return 1;
    }

    my $ret = 1;

    foreach my $i ("INT", "EXT", "DMZ") {
        y2milestone ("Removing dhcpd iface $i");
        SuSEFirewall::RemoveService ("42", "UDP", $i);
        SuSEFirewall::RemoveService ("42", "TCP", $i);
    }
    if ($start_service)
    {
        foreach my $i (@allowed_interfaces) {
            y2milestone ("Adding dhcpd iface %1", $i);
            SuSEFirewall::AddService ("42", "UDP", $i);
            SuSEFirewall::AddService ("42", "TCP", $i);
        }
    }
    if (! Mode::test ())
    {
        Progress::off ();
        $ret = SuSEFirewall::Write () && $ret;
        Progress::on ();
    }
    if ($start_service)
    {
        $ret = SCR::Write (".sysconfig.SuSEfirewall2.FW_SERVICE_DHCPD",
            SuSEFirewall::MostInsecureInterface (\@allowed_interfaces)) && $ret;
    }
    else
    {
        $ret = SCR::Write (".sysconfig.SuSEfirewall2.FW_SERVICE_DHCPD", "no")
            && $ret;
    }

    $ret = SCR::Write (".sysconfig.SuSEfirewall2", undef) && $ret;
    if (! $write_only)
    {
        $ret = SCR::Execute (".target.bash", "test -x /sbin/rcSuSEfirewall2 && /sbin/rcSuSEfirewall2 status && /sbin/rcSuSEfirewall2 restart") && $ret;
    }
    if (! $ret)
    {
        # error report
        Report::Error (_("Error while setting firewall settings occured"));
    }
    return $ret;
}

sub NormalizeFilename {
    my $filename = $_[0];

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

sub ReadDDNSKeys {
    my @globals = SCR::Dir (".dns.named.value");
    my %globals = ();
    foreach my $g (@globals) {
	$globals{$g} = 1;
    }
    @globals = keys (%globals);
    @update_keys = ();
    foreach my $key (@globals) {
        if ($key eq "include")
        {
	    my @filenames = SCR::Read (".dns.named.value.$key");
	    foreach my $filename (@filenames) {
		y2milestone ("Reading include file $filename");
		$filename = NormalizeFilename ($filename);
		my @tsig_keys = AnalyzeTSIGKeyFile ($filename);
		foreach my $tsig_key (@tsig_keys) {
		    y2milestone ("Having key $tsig_key, file $filename");
		    push @update_keys, {
			"filename" => $filename,
			"key" => $tsig_key,
		    };
		}
	    }
	}
    };
}

sub AdaptDDNS {
    my @do_not_copy_chroot = ();

    my @globals = SCR::Dir (".dns.named.value");

    my @includes = SCR::Read (".dns.named.value.include");
    #translate list to hash
    my %includes = ();
    foreach my $i (@includes) {
	my $i = NormalizeFilename ($i);
	$includes{$i} = 1;
    }
    # remove obsolete
    foreach my $i (@deleted_includes) {
	my $file = $i->{"filename"};
	$includes{$file} = 0;
    }
    # add new
    foreach my $i (@new_includes) {
	my $file = $i->{"filename"};
	$includes{$file} = 1;
    }
    #save them back
    foreach my $i (keys (%includes)) {
	if ($includes{$i} != 1)
	{
	    delete $includes{$i};
	}
    }
    @includes = sort (keys (%includes));
    @includes = map {
	"\"$_\"";
    } @includes;

    y2milestone ("Final includes: @includes");
    SCR::Write (".dns.named.value.include", \@includes);

    my $includes = SCR::Read (".sysconfig.named.NAMED_CONF_INCLUDE_FILES");
    @includes = split (/ /, $includes);
    %includes = ();
    foreach my $i (@includes) {
	$includes{$i} = 1;
    }
    # remove obsolete
    foreach my $i (@deleted_includes) {
	my $file = $i->{"filename"};
	$includes{$file} = 0;
    }
    # add new
    foreach my $i (@new_includes) {
	my $file = $i->{"filename"};
	$includes{$file} = 1;
    }
    #save them back
    foreach my $i (keys (%includes)) {
	if ($includes{$i} != 1)
	{
	    delete $includes{$i};
	}
    }
    @includes = sort (keys (%includes));
    $includes = join (" ", @includes);
    SCR::Write (".sysconfig.named.NAMED_CONF_INCLUDE_FILES", $includes);

    unshift @options, {
        "key" => "include",
        "value" => "\"$ddns_file_name\"",
    };

    return 1;
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
    my @old_options = @{SCR::Dir (".dns.named.value.options") || []};
    my @current_options = map {
	$_->{"key"}
    } (@options);
    my @del_options = grep {
	! contains (\@current_options, $_);
    } @old_options;
    foreach my $o (@del_options) {
	SCR::Write (".dns.named.value.options.$o", undef);
    }

    # save the settings
    foreach my $option (@options)
    {
	my $key = $option->{"key"};
	my $value = $option->{"value"};
	# FIXME doesn't work with multiple occurences !!!
	SCR::Write (".dns.named.value.options.$key", [$value]);
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

BEGIN { $TYPEINFO{RemoveZone} = ["function", "boolean", "integer", "boolean"]; }
sub RemoveZone {
    my $zone_index = $_[0];
    my $delete_file = $_[1];

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
    $current_zone_index = $zone_index;

    return $ret;
}

#BEGIN{ $TYPEINFO{ListZones}=["function",["list",["map","string","string"]]];}
#sub ListZones {
#    return map {
#	{
#	    "zone" => $_->{"zone"},
#	    "type" => $_->{"type"},
#	}
#    } @zones;
#}

##------------------------------------
# Functions for accessing the data

BEGIN { $TYPEINFO{SetStartService} = [ "function", "void", "boolean" ];}
sub SetStartService {
    $start_service = $_[0];
    SetModified ();
}

BEGIN { $TYPEINFO{GetStartService} = [ "function", "boolean" ];}
sub GetStartService {
    return Boolean($start_service);
}

BEGIN { $TYPEINFO{SetChrootJail} = [ "function", "void", "boolean" ];}
sub SetChrootJail {
    $chroot = $_[0];
    SetModified ();
}

BEGIN { $TYPEINFO{GetChrootJail} = [ "function", "boolean" ];}
sub GetChrootJail {
    return Boolean($chroot);
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

BEGIN{$TYPEINFO{SetAllowedInterfaces} = ["function","void",["list","string"]];}
sub SetAllowedInterfaces {
    @allowed_interfaces = @{$_[0]};
}

BEGIN { $TYPEINFO{GetAllowedInterfaces} = [ "function", ["list","string"]];}
sub GetAllowedInterfaces {
    return @allowed_interfaces;
}
BEGIN {$TYPEINFO{FetchCurrentZone} = [ "function", ["map", "string", "any"] ]; }
sub FetchCurrentZone {
    return \%current_zone;
}

BEGIN {$TYPEINFO{StoreCurrentZone} = [ "function", "boolean", ["map", "string", "any"] ]; }
sub StoreCurrentZone {
    %current_zone = %{$_[0]};
    return 1;
}

BEGIN {$TYPEINFO{FetchZones} = [ "function", ["list", ["map", "any", "any"] ] ]; }
sub FetchZones {
    return @zones;
}

BEGIN {$TYPEINFO{StoreZones} = [ "function", "void", [ "list", ["map", "any", "any"] ] ]; }
sub StoreZones {
    @zones = @{$_[0]};
    SetModified ();
}

BEGIN{$TYPEINFO{GetGlobalOptions}=["function",["list",["map","any","any"]]];}
sub GetGlobalOptions {
    return @options;
}

BEGIN{$TYPEINFO{SetGlobalOptions}=["function","void",["list",["map","any","any"]]];}
sub SetGlobalOptions {
    @options = @{$_[0]};
    SetModified ();
}

BEGIN{$TYPEINFO{ListTSIGKeys}=["function",["list",["map","string","string"]]];}
sub ListTSIGKeys {
    return @update_keys;
}

# FIXME multiple keys in one file
BEGIN{$TYPEINFO{AnalyzeTSIGKeyFile}=["function",["list","string"],"string"];}
sub AnalyzeTSIGKeyFile {
    my $filename = $_[0];

    y2milestone ("Reading TSIG file $filename");
    $filename = NormalizeFilename ($filename);
    my $contents = SCR::Read (".target.string", $filename);
    if ($contents =~ /.*key[ \t]+([^ \t}{;]+).* {/)
    {
	return ($1);
    }
    return ();
}

BEGIN{$TYPEINFO{AddTSIGKey}=["function", "boolean", "string"];}
sub AddTSIGKey {
    my $filename = $_[0];

    my @tsig_keys = AnalyzeTSIGKeyFile ($filename);
    y2milestone ("Reading TSIG file $filename");
    $filename = NormalizeFilename ($filename);
    my $contents = SCR::Read (".target.string", $filename);
    if (0 != @tsig_keys)
    {
	foreach my $tsig_key (@tsig_keys) {
	    y2milestone ("Having key $tsig_key, file $filename");
	    # remove the key if already exists
	    my @current_keys = grep {
		$_->{"key"} eq $tsig_key;
	    } @update_keys;
	    if (@current_keys > 0)
	    {
		DeleteTSIGKey ($tsig_key);
	    }
	    #now add new one
	    my %new_include = (
		"filename" => $filename,
		"key" => $tsig_key,
	    );
	    push @update_keys, \%new_include;
	    push @new_includes, \%new_include;
	}
	return Boolean (1);
    }
    return Boolean (0);
}

BEGIN{$TYPEINFO{DeleteTSIGKey}=["function", "boolean", "string"];}
sub DeleteTSIGKey {
    my $key = $_[0];
    
    y2milestone ("Removing TSIG key $key");
    #add it to deleted list
    my @current_keys = grep {
	$_->{"key"} eq $key;
    } @update_keys;
    if (@current_keys == 0)
    {
	y2error ("Key not found");
	return Boolean(0);
    }
    foreach my $k (@current_keys) {
	push @deleted_includes, $k;
    }
    #remove it from current list
    @new_includes = grep {
	$_->{"key"} ne $key;
    } @new_includes;
    @update_keys = grep {
	$_->{"key"} ne $key;
    } @update_keys;

    return Boolean (1);
}

##------------------------------------
BEGIN { $TYPEINFO{Read} = ["function", "boolean"]; }
sub Read {

    # DNS server read dialog caption
    my $caption = _("Initializing DNS Server Configuration");

    Progress::New( $caption, " ", 2, [
	# progress stage
	_("Check the environment"),
	# progress stage
	_("Read the settings"),
    ],
    [
	# progress step
	_("Checking the environment..."),
	# progress step
	_("Reading the settings..."),
	# progress step
	_("Finished")
    ],
    ""
    );

    my $sl = 0.5;

    Progress::NextStage ();
    sleep ($sl);

    # Check packages
    if (! (Mode::config () || Require::AreAllPackagesInstalled (["bind"])))
    {
	my $installed = Require::RequireAndConflictTarget (["bind"], [],
	# richtext, %1 is name of package
	    _("For running DNS server, a DNS daemon is required.
YaST2 will install package %1.
"));
	if (! $installed && ! Require::LastOperationCanceled ())
	{
	    # error popup
	    Report::Error (_("Installing required packages failed."));
	}
    }
 
    Progress::NextStage ();
    sleep ($sl);

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
	my @values = SCR::Read (".dns.named.value.options.$key");
	foreach my $value (@values) {
	    push @options, {
		"key" => $key,
		"value" => SCR::Read (".dns.named.value.options.$key"),
	    };
	}
    }

    ReadDDNSKeys ();

    @zones = map {
	my $zonename = $_;
	$zonename =~ s/.*\"(.*)\".*/$1/;
	my $path_el = $_;
	$path_el =~ s/\"/\\\"/g;
	$path_el = "\"$path_el\"";
	my @tmp = SCR::Read (".dns.named.value.$path_el.type");
	my $zonetype = $tmp[0] || "";
	@tmp = SCR::Read (".dns.named.value.$path_el.file");
	my $filename = $tmp[0] || "";
	if (! defined $filename)
	{
	    $filename = $zonetype eq "master" ? "master" : "slave";
	    $filename = "$filename/$zonename";
	}
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
	    @tmp = SCR::Read (".dns.named.value.$path_el.masters") || ();
	    $zd{"masters"} = $tmp[0] || "";
 	    if ($zd{"masters"} =~ /\{.*;\}/)
	    {
		$zd{"masters"} =~ s/\{(.*);\}/$1/
	    }
	}
	else
	{
# TODO hint, forward, .... not supported at the moment
	}
	
	my @zone_options_names = SCR::Dir (".dns.named.value.$path_el");
	my @zone_options = ();
	foreach my $key (@zone_options_names) {
	    my @values = SCR::Read (".dns.named.value.$path_el.$key");
	    foreach my $value (@values) {
		push @zone_options, {
		    "key" => $key,
		    "value" => $value,
		}
	    }
	}
	
	$zd{"file"} = $filename;
	$zd{"type"} = $zonetype;
	$zd{"zone"} = $zonename;
	$zd{"options"} = \@zone_options;
	\%zd;
    } @zone_headers;
    $modified = 0;

    Progress::NextStage ();
    sleep ($sl);

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

    #adapt included files
    $ok = AdaptDDNS () && $ok;

    #save all zones
    @zones_update_actions = ();
    foreach my $z (@zones) {
	$ok = ZoneWrite ($z) && $ok;
    }

    #be sure the named.conf file is saved
    SCR::Write (".dns.named", undef);
    
    #set daemon starting
    SCR::Write (".sysconfig.named.NAMED_RUN_CHROOTED", $chroot ? "yes" : "no");
    SCR::Write (".sysconfig.named", undef);

    if (0 != @zones_update_actions)
    {
	my $ret = SCR::Execute (".target.bash", "/etc/init.d/named restart");
	if ($ret != 0)
	{
	    $ok = 0;
	}
	else
	{
	    UpdateZones (\@zones_update_actions);
	}
    }

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
	"options" => \@options,
	"logging" => \@logging,
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
    @options = @{$settings{"options"} || []};
    @logging = @{$settings{"logging"} || []};

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
    #  summary string, %s is list of DNS zones (their names), coma separated
    push (@ret, sprintf (_("Configured Zones: %s"), $zones_list));
    return @ret;
}


# EOF
