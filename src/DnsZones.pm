#! /usr/bin/perl -w
# File:         modules/DnsZones.pm
# Package:      Configuration of DNS Server
# Summary:      Input and output functions for DNS zones
# Authors:      Jiri Srain <jsrain@suse.cz>
#		Lukas Ocilka <locilka@suse.cz>
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
use DnsRoutines;

use YaPI;
textdomain("dns-server");

YaST::YCP::Import ("Hostname");
YaST::YCP::Import ("String");
YaST::YCP::Import ("Mode");
YaST::YCP::Import ("Ldap");

#use io_routines;
#use check_routines;

our %TYPEINFO;

my $zone_base_config_dn = "";

my $LDAP_RECORD = 'Record';

YaST::YCP::Import ("SCR");
use DnsTsigKeys;
use DnsData qw(@tsig_keys $start_service $chroot @allowed_interfaces
@zones @options @logging $ddns_file_name
$modified $save_all @files_to_delete %current_zone $current_zone_index
$adapt_firewall %firewall_settings $write_only @new_includes @deleted_includes
@zones_update_actions);

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw($zone_base_config_dn);

my @tmp_all_rec_types = ("mx", "ns", "a", "aaaa", "md", "cname", "ptr", "hinfo",
    "minfo", "txt", "spf", "sig", "key", "aaa", "loc", "nxtr", "srv",
    "naptr", "kx", "cert", "a6", "dname");

my @all_rec_types = ();

# See bnc #433899
sub drunkCamelType {
    my $rectype = shift;

    if ($rectype =~ m/^(.)(.*)$/) {
	$rectype = lc($1).uc($2);
    }

    return $rectype;
}

foreach my $one_rectype (@tmp_all_rec_types) {
    push @all_rec_types, drunkCamelType ($one_rectype);
}

##-------------------------------------------------------------------------
##----------------- various routines --------------------------------------

BEGIN{$TYPEINFO{GetFQDN} = ["function", "string"];}
sub GetFQDN {
    my $self = shift;

    my $out = SCR->Execute (".target.bash_output", "/bin/hostname --fqdn");

    if (Mode->test()) {
	return "";
    }

    # standard return
    if ($out->{"exit"} eq "0") {
	my $stdout = $out->{"stdout"};
	my ($ret, $rest) = split ("\n", $stdout, 2);

	return $ret;
    # fallback
    } else {
	my $hostname = SCR->Read (".target.string", "/etc/HOSTNAME");
	my ($ret, $rest) = split ("\n", $hostname, 2);
	y2warning ("Using fallback hostname: ".$ret);

	return $ret;
    }
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

    my $fqdn = $self->GetFQDN();
    if ($fqdn eq "") {
	my $tld = $Hostname::DEFAULT_DOMAIN;
	$fqdn = "linux.$tld";
    }

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
	    "TTL" => "172800",
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

    y2milestone ("Reading zone $zone from $file");

    my $zonemap_ref = SCR->Read (".dns.zone", "/var/lib/named/$file");
    if (! defined ($zonemap_ref))
    {
	return return {};
    }
    my %zonemap = %{$zonemap_ref};
    my %soa = %{$zonemap{"soa"} || {}};
    my %ret = (
	"zone" => $zone,
	"ttl" => $zonemap{"TTL"} || "172800",
	"soa" => \%soa,
    );
    my @original_records = @{$zonemap{"records"} || []};
    my %in_mx = ();
    my %in_prt = ();
    my %in_cname = ();
    my %in_a = ();
    my $previous_key = "$zone.";

    my @records = ();

    # used for ddns updated (needs ns record)
    my $zone_has_ns_record = 0;
    my $search_for_record_key = $zone.".";

    foreach my $record (@original_records) {
	my %r = %{$record};
	my $key = $r{"key"} || "";
	my $type = $r{"type"} || "";
	my $value = $r{"value"} || "";

	if ($key eq "")
	{
	    $key = $previous_key;
	}
	else
	{
	    # bugzilla #189310, "@" is equal to zone name
	    if ($key eq "\@") {
		$key = $zone . ($zone =~ /\.$/ ? "":".");
	    }
	    $previous_key = $key;
	}

	# Handle special cases
	if ($type =~ /^(txt|spf)$/i) {
	    $value =~ s/(^\"|\"$)//g;
	    $value =~ s/\\\"/\"/g;
	}

	push @records, {
	    "key" => $key,
	    "type" => $type,
	    "value" => $value,
	};

	# dynamic update needs zone with at least one NS defined
	if ((uc($type) eq "NS") && ($key =~ /$search_for_record_key$/ || $key eq "") && ($value)) {
	    $zone_has_ns_record = 1;
	}
	
	$ret{"this_zone_had_NS_record_at_start"} = $zone_has_ns_record;
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
    my %current_soa = %{$zone_map{"soa"} || {}};
    while ((my $key, my $value) = each %current_soa)
    {
	$soa{$key} = $value;
    }

    my @records = ();

    my $NS_records = 0;

    # Handle special cases
    foreach my $r (@{$zone_map{"records"}}) {
	my $key = $r->{"key"} || "";
	my $type = $r->{"type"} || "";
	my $value = $r->{"value"} || "";

	if ($type =~ /^(txt|spf)$/i && $value !~ /^\"/ && $value !~ /\"$/) {
	    $value =~ s/\"/\\\"/g;
	    $value = '"'.$value.'"';
	}

	if ($type =~ /^NS/i) {
	    ++$NS_records;
	}

	push @records, {
	    "key" => $key,
	    "type" => $type,
	    "value" => $value,
	};
    }

    # At least one NS record must be set
    if ($NS_records == 0) {
	my $hostname = Hostname->CurrentFQ();
	y2warning ("No NS record set, adding the current hostname: '".$hostname."'");
	push @records, {
	    "key" => $zone_name.'.',
	    "type" => 'NS',
	    "value" => $hostname.'.',
	};
    }

    my %save = (
	"TTL" => $ttl,
	"soa" => \%soa,
	"records" => \@records,
    );
    return SCR->Write (".dns.zone", [$zone_file, \%save]);
}

# This function is a light hack fo NSUPDATE.
# It doesn't touch any commands which aren't add or delete NS record.
# Tt also doesn't touch nsupdates which are editing NS records but are not-right
# for the current zone name.
# This light hack is here because nsupdate needs at least one NS record working for it's updates
# and it would never delete the last record, even user would add another after the removing. So,
# he would have two NS records - the last old one and the new one.
BEGIN{$TYPEINFO{GetSortedUpdateCommands}=["function",["list",["map","any","any"]],["list",["map","any","any"]],"string"];}
sub GetSortedUpdateCommands {
    my $class = shift;
    my @all_actions = @{+shift};
    my $zone_name = shift;
    my @actions = ();

    # $NS_servers->{/server name/} = integer;
    # (..-1) = remove, 0 = do nothing, (+1..) = add
    my $NS_servers = {};
    foreach my $command (@all_actions) {
	if (uc($command->{"type"}) ne "NS") {
	    # pushing all non NS commands
	    push @actions, $command;
	} else {
	    my $command_for_zone = $command->{"key"};
	    $command_for_zone =~ s/\.$//;
	    if ($command_for_zone ne $zone_name) {
		# pushing all NS records for another domain or subdomain
		push @actions, $command;
	    } else {
		# all NS records for THIS domain for the later check
		if (lc($command->{"operation"}) eq "add") {
		    ++$NS_servers->{$command->{"value"}};
		} else {			#  "delete"
		    --$NS_servers->{$command->{"value"}};
		}
	    }
	}
    }

    # at first adding, then removing
    foreach my $one_server (sort {$NS_servers->{$b} <=> $NS_servers->{$a}} (keys %{$NS_servers})) {
	if ($NS_servers->{$one_server} > 0) {
	    push @actions, { "operation" => "add", "type" => "NS", "key" => $zone_name.".", "value" => $one_server };
	} elsif ($NS_servers->{$one_server} < 0) {
	    push @actions, { "operation" => "delete", "type" => "NS", "key" => $zone_name.".", "value" => $one_server };
	}
    }

    return \@actions;
}

# To prevent from showing the key
sub RemoveKeyLine ($) {
    my $command = shift;

    $command =~ s/key[ \t]+([^ \t]+)[ \t]+.*/key $1 __secret_key_has_been_hidden_for_security_reasons__/;

    return $command;
}

BEGIN{$TYPEINFO{UpdateZones}=["function",["list",["map","any","any"]]];}
sub UpdateZones {
    my $self = shift;
    my @zone_descr = @{+shift};

    y2milestone ("Updating zones");
    my $ok = 1;
    foreach my $zone_descr (@zone_descr) {
	my $zone_name = $zone_descr->{"zone"};
	my @actions = ();
	# Undefined "actions" would kill the Perl!
	if (defined $zone_descr->{"actions"}) {
	    my $actions_ref = $zone_descr->{"actions"};
	    @actions = @{$actions_ref};
	}
	my $tsig_key = $zone_descr->{"tsig_key"};
	my $tsig_key_value = DnsTsigKeys->TSIGKeyName2TSIGKey ($tsig_key);

	my @commands = (
	    "server 127.0.0.1",
	    "key $tsig_key $tsig_key_value",
	    "zone $zone_name.",
	);

	my @static_actions;
	foreach my $command (@actions) {
	    if (substr ($command->{"key"}, length ($command->{"key"}) -1, 1) ne ".") {
		$command->{"key"} .= ".".$zone_name;
	    }
	    if (substr ($command->{"key"}, length ($command->{"key"}) -1, 1) ne ".") {
		$command->{"key"} .= ".";
	    }
	    push @static_actions, $command;
	}

	@static_actions = @{$self->GetSortedUpdateCommands(\@static_actions,$zone_name)};

	my @uc = map {
	    my $a = $_;
	    my $operation = $a->{"operation"};
	    my $type = $a->{"type"};
	    my $key = $a->{"key"};
	    my $value = $a->{"value"};
	    my $ttl = $zone_descr->{"ttl"} || "172800";
	    if ($operation ne "add")
	    {
		$ttl = "";
	    }
	    "update $operation $key ".($ttl ? DnsRoutines->NormalizeTime($ttl):"")." $type $value";
	} @static_actions;
	push @commands, @uc;
	push @commands, "";
	push @commands, "";
	my $command = join ("\n", @commands);

	y2milestone ("Running command:\n".RemoveKeyLine($command));
	my $tmpfile = Directory->tmpdir().'/nsupdate_commands';
	SCR->Write ('.target.string', $tmpfile, $command);
	my $xx = SCR->Execute (".target.bash_output",
	    "cat '".String->Quote ($tmpfile)."' | /usr/bin/nsupdate");
    }
    return $ok;
}

# LDAP data

# @param string record type
sub LDAPRecordString {
    return drunkCamelType (shift).$LDAP_RECORD;
}

BEGIN { $TYPEINFO{ZoneReadLdap} = ["function", [ "map", "any", "any" ], "string", "string" ]; }
sub ZoneReadLdap {
    my $self = shift;
    my $zone = shift;
    my $file = shift;

    if ( $zone eq "0.0.127.in-addr.arpa" || $zone eq "localhost")
    {
	return $self->ZoneRead ($zone, $file);
    }

    y2milestone ("Reading zone $zone from LDAP");

    my $zone_dn = "zoneName=$zone,$zone_base_config_dn";

    y2milestone ("Reading zone from LDAP: ".$zone_dn);

    # the search config map
    my %ldap_query = (
        "base_dn" => $zone_dn,
        "scope" => 0,   # top level only
        "map" => 0      # gimme a list (single entry)
    );

    my $found_ref = SCR->Read (".ldap.search", \%ldap_query);

    if (! defined ($found_ref))
    {
	y2warning ("Zone $zone not found in LDAP, ignoring it");
	return {};
    }

    my @found = @{ $found_ref };
    my %zonemap = %{$found[0] || {}};

    my $serial = $self->UpdateSerial ("");
    my @soa_str_lst = @{$zonemap{LDAPRecordString('SOA')}|| ["@ root $serial 3H 1H 1W 1D"]};

    my $soa_str = $soa_str_lst[0];
    my @soa_lst = split (" ", $soa_str);
    @soa_lst = grep {
	$_ ne ""
    } @soa_lst;

    my @rel_lst = @{$zonemap{"relativeDomainName"}};

    my %soa = (
	"expiry" => $soa_lst[5],
	"mail" => $soa_lst[1],
	"minimum" => $soa_lst[6],
	"refresh" => $soa_lst[3],
	"retry" => $soa_lst[4],
	"server" => $soa_lst[0],
	"zone" => $rel_lst[0],
	"serial" => $self->UpdateSerial ($soa_lst[2]),
    );

    my @ttl_lst = @{$zonemap{"dNSTTL"} || []};
    my $ttl = $ttl_lst[0];

    my %ret = (
	"zone" => $zone,
	"ttl" => $ttl,
	"soa" => \%soa,
    );

    # the search config map
    %ldap_query = (
        "base_dn" => $zone_dn,
        "scope" => 2,   # all levels - getting all records
        "map" => 0      # gimme a list (single entry)
    );

    $found_ref = SCR->Read (".ldap.search", \%ldap_query);

    @found = @{$found_ref};

    my @records = ();

    foreach my $record_ref (@found)
    {
	my %record = %{$record_ref};
	my @rel_dn = @{$record{"relativeDomainName"}};
	my $rel_dn = $rel_dn[0];

	foreach my $rec_type (@all_rec_types)
	{
	    my $value_key = $rec_type.$LDAP_RECORD;
	    my @values = @{$record{$value_key} || []};
	    foreach my $value (@values)
	    {
		my %new_rec = (
		    "key" => $rel_dn,
		    "type" => uc ($rec_type),
		    "value" => $value,
		);
		push @records, \%new_rec;
	    }
	}
    }
    $ret{"records"} = \@records;
    return \%ret;
}

sub FillUpTmpLDAPRecords {
    my $ref_found = shift;

    my ($ldap_key, $record_key);
    my $ldap_records = {};

    foreach my $l_record (@{$$ref_found}) {
	$ldap_key = $l_record->{'relativeDomainName'}[0];
	$ldap_records->{$ldap_key} = [] if not defined $ldap_records->{$ldap_key};
	foreach $record_key (keys %{$l_record}) {
	    push @{$ldap_records->{$ldap_key}}, $record_key if ($record_key =~ /^.*$LDAP_RECORD$/);
	}
    }

    return $ldap_records;
}

sub MarkRemovedRecords {
    my $ref_ldap_record = shift;
    my $ref_relative_domain = shift;
    my $ref_all_records = shift;

    # Record is currently in LDAP
    if (defined $$ref_all_records->{$$ref_relative_domain}) {
	# All record types in relative domain
	foreach my $recordtype (@{$$ref_all_records->{$$ref_relative_domain}}) {
	    # The new record does not contain such record type (thus it's removed)
	    if (not defined $$ref_ldap_record{$recordtype}) {
		$$ref_ldap_record{$recordtype} = [];
		y2milestone ("Record ".$recordtype." has been removed from ".$$ref_relative_domain." object");
	    }
	}
    }
}

BEGIN { $TYPEINFO{ZoneFileWriteLdap} = ["function", "boolean", [ "map", "any", "any"]];}
sub ZoneFileWriteLdap {
    my $self = shift;
    my %zone_map = %{+shift};

    my $zone = $zone_map{"zone"};
    my $zone_dn = "zoneName=$zone,$zone_base_config_dn";

    y2milestone ("Saving zone $zone to LDAP");

    my @records = @{$zone_map{"records"} || []};

# create LDAP object

    my %soa = %{$self->GetDefaultSOA ()};
    my %current_soa = %{$zone_map{"soa"} || {}};
    while ((my $key, my $value) = each %current_soa)
    {
	$soa{$key} = $value;
    }
    my @soa_lst = (
	$soa{"server"},
	$soa{"mail"},
	$soa{"serial"},
	DnsRoutines->NormalizeTime ($soa{"refresh"}),
	DnsRoutines->NormalizeTime ($soa{"retry"}),
	DnsRoutines->NormalizeTime ($soa{"expiry"}),
	DnsRoutines->NormalizeTime ($soa{"minimum"}),
    );
    my $soa_record = join (" ", @soa_lst);

    my %ldap_record = (
	"objectClass" => ["dNSZone"],
	"zoneName" => [$zone],
	"relativeDomainName" => ["@"],
	"dNSTTL" => [DnsRoutines->NormalizeTime ($zone_map{"ttl"} || "2D")],
	"dNSClass" => ["IN"],
	LDAPRecordString('SOA') => $soa_record,
    );

    my @current_records = grep {
	my %r = %{$_};
	$r{"key"} eq "@" || $r{"key"} eq $zone."."
    } @records;

    foreach my $rec_ref (@current_records) {
	my $type = LDAPRecordString($rec_ref->{"type"});
	my @cur_vals = @{$ldap_record{$type} || []};
	push @cur_vals, $rec_ref->{"value"};
	$ldap_record{$type} = \@cur_vals;
    }

    # the search config map - to choose add or modify
    my %ldap_query = (
        "base_dn" => $zone_dn,
        "scope" => 0,   # top level only
        "map" => 0,     # gimme a list (single entry)
	"not_found_ok" => 1,
    );

    my %ldap_cmd = (
	"dn" => $zone_dn,
    );

    my $found_ref = SCR->Read (".ldap.search", \%ldap_query);
    y2debug ("Base record: ".Dumper($found_ref));

    my $ldap_records = FillUpTmpLDAPRecords(\$found_ref);

    # Some (sub)records have been removed but the LDAP record have to stay
    foreach my $r ('@', $zone.'.') {
	MarkRemovedRecords (\%ldap_record, \$r, \$ldap_records);
    }
    y2debug ("New base record: ".Dumper(\%ldap_record));

    my $ldap_write = 1;
    if (scalar (@{$found_ref || []}) == 0)
    {
	y2milestone ("Creating new zone record");
	$ldap_write = SCR->Write(".ldap.add", \%ldap_cmd, \%ldap_record);
    }
    else
    {
	y2milestone ("Modifying existing zone record");
	delete $ldap_record{"objectClass"}; # objectclass can be changed by mail-server
	$ldap_write = SCR->Write(".ldap.modify", \%ldap_cmd, \%ldap_record);
    }
    unless ($ldap_write) {
        y2error("LDAP Error (write): ".Ldap->LDAPError());
        Ldap->LDAPErrorMessage('write', Ldap->LDAPError());
        return 0;
    }

    my @all_records = map {
	my %r = %{$_};
	$r{"key"}
    } @records;
    # Never delete the base entry
    push @all_records, "@";

    # the search config map
    %ldap_query = (
        "base_dn" => $zone_dn,
        "scope" => 2,   # all levels - getting all records
        "map" => 0,     # gimme a list (single entry)
	"not_found_ok" => 1,
    );

    $found_ref = SCR->Read (".ldap.search", \%ldap_query) || [];

    my @found = @{$found_ref};
    @found = map {
	my @l = @{$_->{"relativeDomainName"}};
	$l[0];
    } @found;

    $ldap_records = FillUpTmpLDAPRecords(\$found_ref);
    y2debug ("Records currently in LDAP: ".Dumper($ldap_records));
    y2debug ("New state of records: ".Dumper(\@records));

    # Delete removed entries (only fully removed entries will be deleted)
    my @deleted = grep {
	my $current = $_;
	my @equiv = grep {
	    $_ eq $current;
	} @all_records;
	@equiv == 0;
    } @found;

    foreach my $d (@deleted)
    {
	y2milestone ("Removing all records regarding $d");
	$ldap_write = SCR->Write(".ldap.delete", {"dn" => "relativeDomainName=$d,$zone_dn"});
	last unless $ldap_write; # skip the rest
    }
    unless ($ldap_write) {
        y2error("LDAP Error (delete): ".Ldap->LDAPError());
        Ldap->LDAPErrorMessage('write', Ldap->LDAPError());
        return 0;
    }

    # write all the other records
    @all_records = grep {
	! ($_ eq "@" || $_ eq $zone . ".")
    } @all_records;

    my %rec_keys = ();
    foreach my $r (@all_records)
    {
	$rec_keys{$r} = 1;
    }
    foreach my $r (sort (keys (%rec_keys)))
    {
	my $rec_dn = "relativeDomainName=$r,$zone_dn";
	my %ldap_record = (
	    "objectClass" => ["dNSZone"],
	    "zoneName" => [$zone],
	    "relativeDomainName" => [$r],
	    "dNSTTL" => [DnsRoutines->NormalizeTime ($zone_map{"ttl"} || "2D")],
	    "dNSClass" => ["IN"],
	);

	@current_records = grep {
	    my %r = %{$_};
	    $r{"key"} eq $r;
	} @records;

	foreach my $rec_ref (@current_records) {
	    my $type = LDAPRecordString($rec_ref->{"type"});
	    my @cur_vals = @{$ldap_record{$type} || []};
	    push @cur_vals, $rec_ref->{"value"};
	    $ldap_record{$type} = \@cur_vals;
	}

	# Some (sub)records have been removed but the LDAP record have to stay
	MarkRemovedRecords (\%ldap_record, \$r, \$ldap_records);
	y2debug ("New record: ".Dumper(\%ldap_record));

	# the search config map - to choose add or modify
	my %ldap_query = (
	    "base_dn" => $rec_dn,
	    "scope" => 0,   # top level only
	    "map" => 0,     # gimme a list (single entry)
	    "not_found_ok" => 1,
	);

	my %ldap_cmd = (
	    "dn" => $rec_dn,
	);

	my $found_ref = SCR->Read (".ldap.search", \%ldap_query);

	if (scalar (@{$found_ref || []}) == 0)
	{
	    $ldap_write = SCR->Write (".ldap.add", \%ldap_cmd, \%ldap_record);
	    last unless $ldap_write; # skip the rest
	}
	else
	{
	    $ldap_write = SCR->Write (".ldap.modify", \%ldap_cmd, \%ldap_record);
	    last unless $ldap_write; # skip the rest
	}
    }
    unless ($ldap_write) {
        y2error("LDAP Error (write): ".Ldap->LDAPError());
        Ldap->LDAPErrorMessage('write', Ldap->LDAPError());
        return 0;
    }

    return $ldap_write;
}

BEGIN { $TYPEINFO{ZonesDeleteLdap} = ["function", "boolean", [ "list", "string",]];}
sub ZonesDeleteLdap {
    my $self = shift;
    my @current_zones = @{+shift};

    my @current_zones_in_ldap = @{$self->ZonesListLdap ()};
    my @zones_to_delete = grep {
	my $tz = $_;
	my @check_zones = grep {
	    $tz eq $_;
	} @current_zones;
	@check_zones == 0;
    } @current_zones_in_ldap;

    my $ldap_write = 1;

    foreach my $z (@zones_to_delete) {
	y2milestone ("Removing zone $z from LDAP");
	my %request = (
	    "dn" => "zoneName=$z,$zone_base_config_dn",
	    "subtree" => 1,
	);
	$ldap_write = SCR->Write (".ldap.delete", \%request);

	unless ($ldap_write) {
	    y2error("LDAP Error (write): ".Ldap->LDAPError());
	    Ldap->LDAPErrorMessage('write', Ldap->LDAPError());
	    last;
	}
    }

    return $ldap_write;
}

BEGIN{ $TYPEINFO{ZonesListLdap} = ["function", ["list", "string"]];}
sub ZonesListLdap {
    my $self = shift;

    my %ldap_query = (
        "base_dn" => $zone_base_config_dn,
        "scope" => 1,   # top level only
        "map" => 0,     # gimme a list (single entry)
	"not_found_ok" => 1,
    );

    my $found = SCR->Read (".ldap.search", \%ldap_query);
    my @found = @{$found || []};
    @found = map {
	$_->{"zoneName"}[0];
    } @found;
    @found = grep {
	defined ($_);
    } @found;
    return \@found;
}

BEGIN { $TYPEINFO{SetZoneBaseConfigDn} = ["function", "void", "string"];}
sub SetZoneBaseConfigDn {
    my $self = shift;
    my $new_base_config_dn = shift;

    y2milestone ("Setting base zone DN to $new_base_config_dn");
    $zone_base_config_dn = $new_base_config_dn;
}

BEGIN { $TYPEINFO{GetZoneBaseConfigDn} = ["function", "string"];}
sub GetZoneBaseConfigDn {
    my $self = shift;

    return $zone_base_config_dn;
}

1;

# EOF
