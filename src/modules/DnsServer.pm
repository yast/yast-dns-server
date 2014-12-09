#! /usr/bin/perl -w
#
# DnsServer module written in Perl
#

package DnsServer;

use strict;

use YaST::YCP qw(Boolean sformat :LOGGING);
use YaPI;

use Data::Dumper;
use Time::localtime;

textdomain("dns-server");

our %TYPEINFO;

YaST::YCP::Import ("SCR");
YaST::YCP::Import ("Directory");
YaST::YCP::Import ("Ldap");
YaST::YCP::Import ("Mode");
YaST::YCP::Import ("NetworkInterfaces");
YaST::YCP::Import ("PackageSystem");
YaST::YCP::Import ("Popup");
YaST::YCP::Import ("Progress");
YaST::YCP::Import ("Report");
YaST::YCP::Import ("Service");
YaST::YCP::Import ("SuSEFirewall");
YaST::YCP::Import ("Message");
YaST::YCP::Import ("CWMTsigKeys");
YaST::YCP::Import ("NetworkService");
YaST::YCP::Import ("Hostname");
YaST::YCP::Import ("FileUtils");
YaST::YCP::Import ("DnsServerHelperFunctions");
YaST::YCP::Import ("String");

use DnsZones;
use DnsTsigKeys;

use LdapServerAccess;

use DnsData qw(@tsig_keys $start_service $chroot @allowed_interfaces
@zones @options @logging $ddns_file_name
$modified $save_all @files_to_delete %current_zone $current_zone_index
$write_only @new_includes @deleted_includes
@zones_update_actions $firewall_support @new_includes_tsig @deleted_includes_tsig
$local_forwarder);
use DnsRoutines;

my $reverse_zones_connections = 'yast2-dns-server_reverse-zones';

my %reverse_zones_connections_data = ();

my $includes_dir = '/etc/named.d/';

my $forwarders_include = $includes_dir.'forwarders.conf';

my $data_file = Directory->vardir."/dns_server";

# include of forwarders
my $include_defined_in_conf = 0;

my $use_ldap = 0;

my $ldap_available = 0;

my %yapi_conf = ();

#my $modify_named_conf_dynamically = 0;

#my $modify_resolv_conf_dynamically = 0;

my $netconfig_dns_policy = "";

my @acl = ();

my @logging = ();

my $ldap_server = "";

my $ldap_port = "";

my $ldap_domain = "";

my $ldap_config_dn = "";

my $configuration_timestamp = "";

my $configfile = '/etc/named.conf';

my %zonename_to_filename = ();

##-------------------------------------------------------------------------
##----------------- various routines --------------------------------------

sub contains {
    my $self = shift;
    my @list = @{+shift};
    my $value = shift;

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

# System zones are not allowed to be edited in YaST DNS Server
#
# @param [String] zone name
# @return [Boolean] whether zone is a system one (included in bind package)
sub is_system_zone {
    my $zone_name = shift;

    return (
        $zone_name eq "localhost" ||
        $zone_name eq "0.0.127.in-addr.arpa" ||
        $zone_name =~ /^(0\.)+ip6.arpa$/ ||
        $zone_name eq "."
    )
}

##------------------------------------
# Routines for reading/writing configuration

BEGIN { $TYPEINFO{ZoneWrite} = ["function", "boolean", [ "map", "any", "any" ] ]; }
sub ZoneWrite {
    my $self = shift;
    my %zone_map = %{+shift};

    my $zone_name = $zone_map{"zone"} || "";
    if ($zone_name eq "")
    {
	y2error ("Trying to save unnamed zone, aborting");
	return 0;
    }

    # Do not write system zones to LDAP (bnc#746401)
    if ($use_ldap && is_system_zone($zone_name))
    {
	y2milestone ("Using LDAP, skipping system zone $zone_name");
	return 1;
    }

    if ($save_all) {
	y2milestone ("Saving all zones, flagging ".$zone_name." zone as modified");
	$zone_map{"modified"} = 1;
    }

    # zone not modified (it's not modified if the flag is not set)
    if (! (defined $zone_map{"modified"} ? $zone_map{"modified"} : 0))
    {
	y2milestone ("Skipping zone $zone_name, wasn't modified");
	return 1;
    }

    my $zone_file = $zone_map{"file"} || "";
    # creating temporary zone file if zone is slave
    if ($zone_file eq "" && defined $zone_map{"type"} && $zone_map{"type"} eq "slave") {
	$zone_file = "slave/$zone_name";
    } elsif ($zone_file eq "" && defined $zone_map{"type"} && $zone_map{"type"} eq "forward") {
	$zone_file = "";
    # otherwise it is master
    } elsif ($zone_file eq "") {
	$zone_file = "master/$zone_name";
    }

    my $allow_update = 0;
    foreach my $opt_ref (@{$zone_map{"options"} || []})
    {
	if ($opt_ref->{"key"} eq "allow-update")
	{
	    $allow_update = 1;
	}
    }

    if ($allow_update && @tsig_keys > 0 && $zone_file =~ /^master\/(.+)/)
    {
	my $new_zone_file = $1;
	$new_zone_file = "dyn/$new_zone_file";
	while (SCR->Read (".target.size", "/var/lib/named/$new_zone_file") > 0)
	{
	    $new_zone_file = "$new_zone_file" . "X";
	}
	SCR->Execute (".target.bash", "test -f /var/lib/named/$zone_file && /bin/mv /var/lib/named/$zone_file /var/lib/named/$new_zone_file");
	y2milestone ("Zone file $zone_file moved to $new_zone_file");
	$zone_file = $new_zone_file;
    }
    elsif (!$allow_update && $zone_file =~ /^dyn\/(.+)/) {
	my $new_zone_file = $1;
	$new_zone_file = "master/$new_zone_file";
	while (SCR->Read (".target.size", "/var/lib/named/$new_zone_file") > 0)
	{
	    $new_zone_file = "$new_zone_file" . "X";
	}
	SCR->Execute (".target.bash", "test -f /var/lib/named/$zone_file && /bin/mv /var/lib/named/$zone_file /var/lib/named/$new_zone_file");
	SCR->Execute (".target.bash", "test -f /var/lib/named/".$zone_file.".jnl && /bin/rm /var/lib/named/".$zone_file.".jnl");
	y2milestone ("Zone file $zone_file moved to $new_zone_file");
	$zone_file = $new_zone_file;
    }
    elsif ($zone_map{"is_new"})
    {
	# deleted and created again, bugzilla #199926
	if (defined $zonename_to_filename{$zone_name} && $zonename_to_filename{$zone_name} ne "") {
	    $zone_file = $zonename_to_filename{$zone_name};
	    y2milestone ("Reusing zone file $zone_file");
	} else {
	    while (SCR->Read (".target.size", "/var/lib/named/$zone_file") > 0)
	    {
		$zone_file = "$zone_file" . "X";
	    }
	}
	y2milestone ("Zone $zone_name is new, zone file set to $zone_file");
    }
    $zone_map{"file"} = $zone_file;

    #save changed of named.conf
    my $path_comp = "zone \"$zone_name\" in";
    my $base_path = ".dns.named.value.\"\Q$path_comp\E\"";
    SCR->Write ("$base_path.type", [$zone_map{"type"} || "master"]);

    my @old_options = @{SCR->Dir ($base_path) || []};
    my @save_options = map {
	$_->{"key"};
    } @{$zone_map{"options"}};
    my @del_options = grep {
	! $self->contains (\@save_options, $_);
    } @old_options;
    foreach my $o (@del_options) {
	SCR->Write ("$base_path.\"\Q$o\E\"", undef);
    };

    my @tsig_keys = ();
    
    # dynamic update needs zone with at least one NS defined
    my $this_zone_had_NS_record_at_start = 0;
    if (defined $zone_map{"this_zone_had_NS_record_at_start"}) {
	$this_zone_had_NS_record_at_start = $zone_map{"this_zone_had_NS_record_at_start"};
    }

    foreach my $o (@{$zone_map{"options"}}) {
	my $key = $o->{"key"};
	my $val = $o->{"value"};
	SCR->Write ("$base_path.\"\Q$key\E\"", [$val]);
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
	if ($use_ldap)
	{
	    DnsZones->ZoneFileWriteLdap (\%zone_map);
	}
	# normal file-write - if has_no_keys or is_new or not-dynamically-updated or had not any NS when editing started
	elsif (@tsig_keys == 0 || $zone_map{"is_new"} || ! $allow_update || ! $this_zone_had_NS_record_at_start)
	{
	    if ($allow_update && ! $this_zone_had_NS_record_at_start) {
		y2milestone("Zone $zone_name has no NS records defined yet now, dynamic updated would not work!");
	    }
	    DnsZones->ZoneFileWrite (\%zone_map);
	}
	else
	{
	# dynamic updates, needs at least one NS server
	    y2milestone ("Updating zone $zone_name dynamically");
	    if ($zone_map{"soa_modified"})
	    {
		DnsZones->UpdateSOA (\%zone_map);
	    }
	    my %um = (
		"actions" => $zone_map{"update_actions"},
		"zone" => $zone_name,
		"tsig_key" => $tsig_keys[0],
		"ttl" => $zone_map{"ttl"},
	    );
	    push @zones_update_actions, \%um;
	}

	# write existing keys
	SCR->Write ("$base_path.file", ["\"$zone_file\""]);
    }
    elsif ($zone_type eq "slave" || $zone_type eq "stub")
    {
	my $masters = $zone_map{"masters"} || "";
	if (! $masters =~ /\{.*;\}/)
	{
	    $zone_map{"masters"} = "{$masters;}";
	}
        SCR->Write ("$base_path.masters", [$zone_map{"masters"} || ""]);

	# temporary file for slave zone
	if ($zone_type eq "slave") {
	    # only creating record in named.conf
	    # named should create the temporary file by itself
	    SCR->Write ("$base_path.file", ["\"$zone_file\""]);
	}
    }
    elsif ($zone_type eq "forward")
    {
	SCR->Write ("$base_path.forwarders", [$zone_map{"forwarders"} || "{}"]);
    }
    elsif ($zone_type eq "hint")
    {
	SCR->Write ("$base_path.file", ["\"$zone_file\""]);
    }

    SCR->Write ("$base_path.type", [$zone_map{"type"} || "master"]);

    return 1;
}

sub ReadDDNSKeys {
    my $self = shift;

    DnsTsigKeys->InitTSIGKeys ();
    my $includes = SCR->Read (".sysconfig.named.NAMED_CONF_INCLUDE_FILES")|| "";
    my @includes = split (/ /, $includes);
    foreach my $filename (@includes) {
	if ($filename ne "") {
	    y2milestone ("Reading include file $filename");
	    $filename = $self->NormalizeFilename ($filename);
	    my @tsig_keys = @{CWMTsigKeys->AnalyzeTSIGKeyFile ($filename) ||[]};

	    foreach my $tsig_key (@tsig_keys) {
		y2milestone ("Having key $tsig_key, file $filename");
		DnsTsigKeys->PushTSIGKey ({
		    "filename" => $filename,
		    "key" => $tsig_key,
		});
	    }
	}
    };
}

sub AdaptDDNS {
    my $self = shift;

    my @do_not_copy_chroot = ();

    my @globals = @{SCR->Dir (".dns.named.value") || []};

    my $includes = SCR->Read (".sysconfig.named.NAMED_CONF_INCLUDE_FILES")|| "";
    my @includes = split (/ /, $includes);
    my %includes = ();
    foreach my $i (@includes) {
	$includes{$i} = 1;
    }
    # remove obsolete TSIGs
    foreach my $i (@deleted_includes_tsig) {
	$includes{$i} = 0;
    }
    # add new TSIGs
    foreach my $i (@new_includes_tsig) {
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

    y2milestone ("INCLUDES: ".$includes);

    SCR->Write (".sysconfig.named.NAMED_CONF_INCLUDE_FILES", $includes);

    return 1;
}

BEGIN { $TYPEINFO{SaveGlobals} = [ "function", "boolean" ]; }
sub SaveGlobals {
    my $self = shift;

    #delete all deleted zones first
    my @old_sections = @{SCR->Dir (".dns.named.section") || []};
    my @old_zones = grep (/^zone/, @old_sections);
    my @current_zones = map {
	my %zone = %{$_};
	"zone \"$zone{\"zone\"}\" in";
    } @zones;
    my @del_zones = grep {
	! $self->contains (\@current_zones, $_);
    } @old_zones;

    # Do not remove system zones
    @del_zones = grep {
        $_ =~ /^zone[ \t]+\"([^ \t]+)\".*/;
        my $zone = $1;
        !is_system_zone($zone)
    } @del_zones;

    if (@del_zones > 0) {
        y2milestone ("Deleting zones @del_zones");
        foreach my $z (@del_zones) {
            $z =~ /^zone[ \t]+\"([^ \t]+)\".*/;
            $z = $1;
            y2milestone("Deleting zone: ".$z);
            $z = "zone \"$z\" in";
            SCR->Write (".dns.named.section.\"\Q$z\E\"", undef);
        }
    }

    if ($use_ldap)
    {
	my @zone_names = map {
	    my %zone = %{$_};
	    $zone{"zone"};
	} @zones;

	unless (DnsZones->ZonesDeleteLdap (\@zone_names)) {
	    y2error ("Cannot delete selected zones");
	    return 0;
	}
    }

    # delete all removed options
    my @old_options = @{SCR->Dir (".dns.named.value.options") || []};
    my @current_options = map {
	$_->{"key"}
    } (@options);
    my @del_options = grep {
	! $self->contains (\@current_options, $_);
    } @old_options;

    ### Handling 'forwarders' -->
    my $forwarders_include_record = "\"".$forwarders_include."\"";

    # Some 'forwarders' values are defined
    my $forwarders_defined  = (scalar (grep { $_->{"key"} eq "forwarders"} @options ) != 0);
    # Forwarders external file is already included
    my $forwarders_included = (scalar (grep { $_->{"key"} eq "include" && $_->{"value"} eq $forwarders_include_record } @options) != 0);

    # Remove them from options because they will be written into
    # an included file generated by netconfig
    push @del_options, "forwarders";

    # BNC #484736: forwarders file has to be included if it is not yet
    if (!$forwarders_included) {
	y2milestone("Including forwarders file ".$forwarders_include);
	push @options, { "key" => "include", "value" => $forwarders_include_record };
    }
    ### <-- Handling 'forwarders'

    foreach my $o (@del_options)
    {
	SCR->Write (".dns.named.value.options.\"\Q$o\E\"", undef);
    }

    # save the settings
    my %opt_map = ();
    foreach my $option (@options)
    {
	my $key = $option->{"key"};
	my $value = $option->{"value"};
	my @values = @{$opt_map{$key} || []};
	push @values, $value;
	$opt_map{$key} = \@values;
    }

    # are forwarders in configuration?
    my $forwarders_found = 0;
    foreach my $key (sort (keys (%opt_map)))
    {
	# According to FATE #303386 and BNC #484736, forwarders are no longer
	# written by YaST directly but generated by 'netconfig' from sysconfig entries
	if ($key eq "forwarders") {
	    # handling an exception
	    if (defined @{$opt_map{$key}}[0] && @{$opt_map{$key}}[0] ne "") {
		$forwarders_found = 1;
		my $fwd_list = @{$opt_map{$key}}[0];
		$fwd_list =~ s/[\{,\}, ]//g;
		$fwd_list = join(" ", split (/;/, $fwd_list));
		SCR->Write(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SERVERS", $fwd_list);
		y2milestone( "Wrote NETCONFIG_DNS_STATIC_SERVERS: ".$fwd_list);
	    }
	} else {
	    my @values = @{$opt_map{$key} || []};
	    SCR->Write (".dns.named.value.options.\"\Q$key\E\"", \@values);
	}
    }
    # forwarders not defined, but they must be at least empty
    if (!$forwarders_found) {
	SCR->Write(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SERVERS", "");
	y2milestone ("Wrote -empty- NETCONFIG_DNS_STATIC_SERVERS");
    }

    # delete all removed logging options
    my @old_logging = ();
    if (scalar (grep (/logging/, @{SCR->Dir (".dns.named.section") || []})) > 0)
    {
	@old_logging = @{SCR->Dir (".dns.named.value.logging") || []};
    }
    my @current_logging = map {
	$_->{"key"}
    } (@logging);
    my @del_logging = grep {
	! $self->contains (\@current_logging, $_);
    } @old_logging;
    foreach my $o (@del_logging) {
	SCR->Write (".dns.named.value.logging.\"\Q$o\E\"", undef);
    }

    # save the logging settings
    my %log_map = ();
    foreach my $logopt (@logging)
    {
	my $key = $logopt->{"key"};
	my $value = $logopt->{"value"};
	my @values = @{$log_map{$key} || []};
	push @values, $value;
	$log_map{$key} = \@values;
    }
    foreach my $key (sort (keys (%log_map)))
    {
	my @values = @{$log_map{$key} || []};
	SCR->Write (".dns.named.value.logging.\"\Q$key\E\"", \@values);
    }

    # really save the file
    return SCR->Write (".dns.named", undef);
}



##------------------------------------
# Store/Find/Select/Remove a zone

BEGIN { $TYPEINFO{StoreZone} = ["function", "boolean"]; }
sub StoreZone {
    my $self = shift;

    $current_zone{"modified"} = 1;
    my %tmp_current_zone = %current_zone;
    if ($current_zone_index == -1)
    {
	push (@zones, \%tmp_current_zone);
    }
    else
    {
	$zones[$current_zone_index] = \%tmp_current_zone;
    }

    $self->SetModified ();

    return 1;
}

BEGIN { $TYPEINFO{FindZone} = ["function", "integer", "string"]; }
sub FindZone {
    my $self = shift;
    my $zone_name = shift;

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
    my $self = shift;
    my $zone_index = shift;
    my $delete_file = shift;

    if ($delete_file)
    {
	my %zone_map = %{$zones[$zone_index]};
	my $filename = DnsZones->AbsoluteZoneFileName ($zone_map{"file"});
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
    my $self = shift;
    my $zone_index = shift;

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
	my %new_soa = %{DnsZones->GetDefaultSOA ()};
	%current_zone = (
	    "soa_modified" => 1,
	    "modified" => 1,
	    "type" => "master",
	    "soa" => \%new_soa,
	    "ttl" => "2D",
	    "is_new" => 1,
	);
    }
    else
    {
	%current_zone = %{$zones[$zone_index]};
	if (! ($current_zone{"modified"}))
	{
	    my $serial = $current_zone{"soa"}{"serial"};
	    $serial = DnsZones->UpdateSerial ($serial);
	    $current_zone{"soa"}{"serial"} = $serial;
	}
    }
    $current_zone_index = $zone_index;
    y2milestone ("Selected zone with index $current_zone_index");

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
    my $self = shift;
    $start_service = shift;

    $self->SetModified ();
}

BEGIN { $TYPEINFO{GetStartService} = [ "function", "boolean" ];}
sub GetStartService {
    my $self = shift;

    return $start_service;
}

sub UseLdapModified {
    my $self = shift;

    $self->SetModified ();
    # Save all zones as they are into the new config location (LDAP/files)
    $save_all = 1;
}

BEGIN { $TYPEINFO{SetUseLdap} = [ "function", "boolean", "boolean" ];}
sub SetUseLdap {
    my $self = shift;
    my $new_use_ldap = shift;

    if ($new_use_ldap) {
	# trying init LDAP if use_ldap selected
	my $success = $self->LdapInit (1, 1);

	if (!$success) {
	    return 0;
	}
    }

    $use_ldap = $new_use_ldap;
    y2milestone ("Using LDAP set to: ".$use_ldap);

    $self->UseLdapModified();

    return 1;
}

BEGIN { $TYPEINFO{GetUseLdap} = [ "function", "boolean" ];}
sub GetUseLdap {
    my $self = shift;

    return $use_ldap;
}

BEGIN { $TYPEINFO{SetChrootJail} = [ "function", "void", "boolean" ];}
sub SetChrootJail {
    my $self = shift;
    $chroot = shift;
    if ($chroot !~ /^[01]$/) {
	y2error("Chroot was set to '".$chroot."'");
    }

    $self->SetModified ();
}

BEGIN { $TYPEINFO{GetChrootJail} = [ "function", "boolean" ];}
sub GetChrootJail {
    my $self = shift;

    return $chroot;
}

BEGIN { $TYPEINFO{SetModified} = ["function", "void" ]; }
sub SetModified {
    my $self = shift;

    $modified = 1;
}

BEGIN { $TYPEINFO{WasModified} = ["function", "boolean" ]; }
sub WasModified {
    my $self = shift;

    return $modified;
}

BEGIN { $TYPEINFO{SetWriteOnly} = ["function", "void", "boolean" ]; }
sub SetWriteOnly {
    my $self = shift;
    $write_only = shift;
}

BEGIN{$TYPEINFO{SetAllowedInterfaces} = ["function","void",["list","string"]];}
sub SetAllowedInterfaces {
    my $self = shift;
    @allowed_interfaces = @{+shift};
}

BEGIN { $TYPEINFO{GetAllowedInterfaces} = [ "function", ["list","string"]];}
sub GetAllowedInterfaces {
    my $self = shift;

    return \@allowed_interfaces;
}
BEGIN {$TYPEINFO{FetchCurrentZone} = [ "function", ["map", "string", "any"] ]; }
sub FetchCurrentZone {
    my $self = shift;

    return \%current_zone;
}

BEGIN {$TYPEINFO{StoreCurrentZone} = [ "function", "boolean", ["map", "string", "any"] ]; }
sub StoreCurrentZone {
    my $self = shift;
    %current_zone = %{+shift};

    return 1;
}

BEGIN {$TYPEINFO{FetchZones} = [ "function", ["list", ["map", "any", "any"] ] ]; }
sub FetchZones {
    my $self = shift;

    return \@zones;
}

BEGIN {$TYPEINFO{StoreZones} = [ "function", "void", [ "list", ["map", "any", "any"] ] ]; }
sub StoreZones {
    my $self = shift;
    @zones = @{+shift};

    $self->SetModified ();
}

BEGIN{$TYPEINFO{GetGlobalOptions}=["function",["list",["map","string","any"]]];}
sub GetGlobalOptions {
    my $self = shift;

    return \@options;
}

BEGIN{$TYPEINFO{SetGlobalOptions}=["function","void",["list",["map","string","any"]]];}
sub SetGlobalOptions {
    my $self = shift;
    @options = @{+shift};

    $self->SetModified ();
}

BEGIN{$TYPEINFO{GetLoggingOptions}=["function",["list",["map","string","any"]]];}
sub GetLoggingOptions {
    my $self = shift;

    return \@logging;
}

BEGIN{$TYPEINFO{SetLoggingOptions}=["function","void",["list",["map","string","any"]]];}
sub SetLoggingOptions {
    my $self = shift;
    @logging = @{+shift};

    $self->SetModified ();
}

BEGIN{$TYPEINFO{StopDnsService} = ["function", "boolean"];}
sub StopDnsService {
    if (Service->Stop("named"))
    {
	return 1;
    }

    y2error ("Stopping DNS daemon failed");
    return 0;
}

BEGIN{$TYPEINFO{GetDnsServiceStatus} = ["function", "boolean"];}
sub GetDnsServiceStatus {
    if (Service->Status("named") == 0)
    {
	return 1;
    }

    return 0;
}

BEGIN{$TYPEINFO{StartDnsService} = ["function", "boolean"];}
sub StartDnsService { 
    if (Service->Restart("named"))
    {
        return 1;
    }

    y2error ("Starting DNS daemon failed");
    return 0;
}

BEGIN{$TYPEINFO{GetNetconfigDNSPolicy} = ["function","string"];}
sub GetNetconfigDNSPolicy{
    my $self = shift;

    return $netconfig_dns_policy;
}

BEGIN{$TYPEINFO{SetNetconfigDNSPolicy} = ["function","void","string"];}
sub SetNetconfigDNSPolicy{
    my $self = shift;
    $netconfig_dns_policy = shift;
    $self->SetModified ();
}

BEGIN{$TYPEINFO{GetLocalForwarder} = ["function","string"];}
sub GetLocalForwarder {
    my $self = shift;

    return "resolver" if (not defined $local_forwarder or $local_forwarder eq "");
    return $local_forwarder;
}

BEGIN{$TYPEINFO{SetLocalForwarder} = ["function","boolean","string"];}
sub SetLocalForwarder {
    my $self = shift;
    my $new_local_forwarder = shift;

    if (not defined $new_local_forwarder) {
        y2error("New local forwarder must be defined");
        return 0;
    } elsif (not defined $local_forwarder or $local_forwarder ne $new_local_forwarder) {
        $local_forwarder = $new_local_forwarder;
        y2milestone("New local forwarder: ".$local_forwarder);
        $self->SetModified();
    }

    return 1;
}

BEGIN{$TYPEINFO{GetAcl} = ["function",["list","string"]];}
sub GetAcl {
    my $self = shift;

    return \@acl;
}


BEGIN{$TYPEINFO{SetAcl} = ["function","void",["list","string"]];}
sub SetAcl {
    my $self = shift;
    @acl = @{+shift};
}
   

##------------------------------------

BEGIN { $TYPEINFO{AutoPackages} = ["function", ["map","any","any"]];}
sub AutoPackages {
    my $self = shift;

    return {
	"install" => ["bind"],
	"remove" => [],
    }
}

BEGIN { $TYPEINFO{GetConfigurationStat} = ["function", "string"]; }
sub GetConfigurationStat {
    my $class = shift;

    unless (FileUtils->Exists ($configfile)) {
        y2error('Cannot stat file '.$configfile.', file does not exist');
        return undef;
    }

    my $ret = SCR->Execute (".target.bash_output",
	"stat --format='rights: %a, blocks: %b, size: %s, owner: %u:%g changed: %Z, modifyied: %Y' ".$configfile
    );
    chop ($ret->{'stdout'});
    if ($ret->{'exit'} != 0) {
	y2warning("Cannot read stat of the file '".$configfile."', ".$ret->{'stderr'});
	return "0";
    }
    y2milestone("Stat of the file '".$configfile."' is '".$ret->{'stdout'}."'");
    return $ret->{'stdout'};
}

BEGIN { $TYPEINFO{Read} = ["function", "boolean"]; }
sub Read {
    my $self = shift;

    # DNS server read dialog caption
    my $caption = __("Initializing DNS Server Configuration");

    Progress->New( $caption, " ", 4, [
	# progress stage
	__("Check the environment"),
	# progress stage
	__("Flush caches of the DNS daemon"),
	# progress stage
	__("Read the firewall settings"),
	# progress stage
	__("Read the settings"),
    ],
    [
	# progress step
	__("Checking the environment..."),
	# progress step
	__("Flushing caches of the DNS daemon..."),
	# progress step
	__("Reading the firewall settings..."),
	# progress step
	__("Reading the settings..."),
	# progress step
	__("Finished")
    ],
    ""
    );

    Progress->NextStage ();

    # Requires confirmation when NM is used
    if (! Mode->test () && ! NetworkService->ConfirmNetworkManager()) {
	return 0;
    }

    # Check packages
    if (! Mode->test () && ! PackageSystem->CheckAndInstallPackagesInteractive (["bind"]))
    {
	return 0;
    }

#    if (ProductFeatures->GetFeature ("globals", "ui_mode") eq "expert") {
	$self->LdapInit (0, 0);
#    }
 
    Progress->NextStage ();

    my $started = $self->GetDnsServiceStatus ();
    $self->StopDnsService ();
    if ($started)
    {
	$self->StartDnsService ();
    }

    Progress->NextStage ();
    
    my $current_progress = Progress->set(0);
    SuSEFirewall->Read();
    Progress->set($current_progress);

    Progress->NextStage ();

    if (FileUtils->Exists ($configfile)) {
        y2milestone('Converting configfile: ', SCR->Execute ('.dns.named_conf_convert', $configfile));
    } else {
        y2error('Config file '.$configfile.' does not exist, file cannot be converted');
    }

    $configuration_timestamp = $self->GetConfigurationStat();

    # Information about the daemon
    $start_service = Service->Enabled ("named");
    y2milestone ("Service start: ".$start_service);
    $chroot = SCR->Read (".sysconfig.named.NAMED_RUN_CHROOTED") || "yes";
    $chroot = $chroot eq "yes"
	    ? 1
	    : 0;
    y2milestone ("Chroot: $chroot");

    $netconfig_dns_policy = SCR->Read(".sysconfig.network.config.NETCONFIG_DNS_POLICY") || "";
    y2milestone ("NETCONFIG_DNS_POLICY: $netconfig_dns_policy");

    $local_forwarder = SCR->Read(".sysconfig.network.config.NETCONFIG_DNS_FORWARDER") || "resolver";
    y2milestone ("NETCONFIG_DNS_FORWARDER: $local_forwarder");

    my @zone_headers = @{SCR->Dir (".dns.named.section") || []};
    @zone_headers = grep (/^zone/, @zone_headers);
    y2milestone ("Read zone headers @zone_headers");

    @options = ();
    my @opt_names = @{SCR->Dir (".dns.named.value.options") || []};
    if (! @opt_names)
    {
	@opt_names = ();
    }
    my %opt_hash = ();
    foreach my $opt_name (@opt_names) {
	$opt_hash{$opt_name} = 1;
    }

    my $key;

    @opt_names = sort (keys (%opt_hash));
    my $forwarders_in_options = "";
    
    my $forwarders_value = "";
    my $forwarders_include_record = "\"".$forwarders_include."\"";
    foreach $key (@opt_names) {
	my @values = @{SCR->Read (".dns.named.value.options.$key") || []};
	foreach my $value (@values) {
	    if ($key eq "forwarders") {
#		$forwarders_in_options = $value;
		next;
	    }
	    push @options, {
		"key" => $key,
		"value" => $value,
	    };
	    if ($key eq "include" && $value eq $forwarders_include_record) {
		$include_defined_in_conf = 1;
#		$forwarders_value = SCR->Read (".dns.named-forwarders", $forwarders_include) || "";
	    }
	}
    }
    $forwarders_value = SCR->Read(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SERVERS") || "";
    $forwarders_value = join("; ", split( " ", $forwarders_value));
    y2milestone ("NETCONFIG_DNS_STATIC_SERVERS: $forwarders_value");
    # no forwarders are defined in single file or file doesn't exist
    # but forwarders are defined right in options
#    if (!$forwarders_value && $forwarders_in_options) {
#	$forwarders_value = $forwarders_in_options;
#    }
    push @options, { "key" => "forwarders", "value" => $forwarders_value, };

    @logging = ();
    my @log_names = ();
    if (scalar (grep (/logging/, @{SCR->Dir (".dns.named.section") || []})) > 0)
    {
	@log_names = @{SCR->Dir (".dns.named.value.logging") || []};
    }
    if (! @log_names)
    {
	@log_names = ();
    }
    my %log_hash = ();
    foreach my $log_name (@log_names) {
	$log_hash{$log_name} = 1;
    }
    @log_names = sort (keys (%log_hash));
    foreach $key (@log_names) {
	my @values = @{SCR->Read (".dns.named.value.logging.$key") || []};
	foreach my $value (@values) {
	    push @logging, {
		"key" => $key,
		"value" => $value,
	    };
	}
    }

    @acl = @{SCR->Read (".dns.named.value.acl") || {}};

    $self->ReadDDNSKeys ();

    # FATE #304401: IPv6 support in DNS server configuration
    # Automatically created reverse zones from forward ones
    my $read_from = Directory->vardir()."/".$reverse_zones_connections;
    if (FileUtils->Exists ($read_from)) {
	y2milestone ("Reading: ".$read_from);
	%reverse_zones_connections_data = %{SCR->Read (".target.ycp", $read_from)};
    }

    @zones = map {
	my $zonename = $_;
	$zonename =~ s/.*\"(.*)\".*/$1/;
	my $path_el = $_;
	$path_el = "\"\Q$path_el\E\"";
	my @tmp = @{SCR->Read (".dns.named.value.$path_el.type") || []};
	my $zonetype = $tmp[0] || "";
	@tmp = @{SCR->Read (".dns.named.value.$path_el.file") || []};
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
	my %zd = (
	    "type" => $zonetype
	);
	# ZONE TYPE 'master'
	if ($zonetype eq "master")
	{
	    # bugzilla #199926
	    $zonename_to_filename{$zonename} = $filename;

	    if ($use_ldap)
	    {
		%zd = %{DnsZones->ZoneReadLdap ($zonename, $filename)};
	    }
	    else
	    {
		%zd = %{DnsZones->ZoneRead ($zonename, $filename)};
	    }

	    if ($reverse_zones_connections_data{$zonename}) {
		$zd{"connected_with"} = $reverse_zones_connections_data{$zonename};
		y2milestone ("Zone '".$zonename."' is connected with '".$zd{"connected_with"}."'");
	    }
	}
	# ZONE TYPE 'slave' or 'stub'
	elsif ($zonetype eq "slave" || $zonetype eq "stub")
	{
	    @tmp = @{SCR->Read (".dns.named.value.$path_el.masters") || []};
	    $zd{"masters"} = $tmp[0] || "";
 	    if ($zd{"masters"} =~ /\{.*;\}/)
	    {
		$zd{"masters"} =~ s/\{(.*);\}/$1/
	    }
	}
	# ZONE TYPE 'forward'
	elsif ($zonetype eq "forward") {
	    @tmp = @{SCR->Read (".dns.named.value.$path_el.forwarders") || []};
	    $zd{"forwarders"} = $tmp[0] || "";
 	    if ($zd{"forwarders"} =~ /\{.*;\}/)
	    {
		$zd{"forwarders"} =~ s/\{(.*);\}/$1/
	    }
	}
	else
	{
# TODO hint, .... not supported at the moment
	}
	
	my @zone_options_names = @{SCR->Dir (".dns.named.value.$path_el")|| []};
	my @zone_options = ();
	foreach $key (@zone_options_names) {
	    my @values = @{SCR->Read (".dns.named.value.$path_el.\"\Q$key\E\"") || []};
	    foreach my $value (@values) {
		push @zone_options, {
		    "key" => $key,
		    "value" => $value,
		}
	    }
	}

	if (scalar (keys (%zd)) > 0)
	{	
	    $zd{"file"} = $filename || "";
	    $zd{"type"} = $zonetype || "";
	    $zd{"zone"} = $zonename || "";
	    $zd{"options"} = \@zone_options;
	}
	\%zd;
    } @zone_headers;

    @zones = grep {
	scalar (keys (%{$_})) > 0
    } @zones;

    # System zones cannot be edited in Yast
    @zones = grep {
        ! is_system_zone($_->{"zone"})
    } @zones;

    $modified = 0;

    Progress->NextStage ();

    return 1;
}

BEGIN { $TYPEINFO{GetWhichZonesAreConnectedWith} = ["function", ["list", "string"], "string"]; }
sub GetWhichZonesAreConnectedWith {
    my $class = shift;
    my $zone = shift || '';

    if ($zone eq '') {
	y2error ("Undefined zone");
	return undef;
    }

    my @ret;

    foreach my $z (@zones) {
	if (defined $z->{"connected_with"} && $z->{"connected_with"} eq $zone) {
	    push @ret, $z->{"zone"};
	}
    }

    return \@ret;
}

# Writes forwarding settings and updates the system using netconfig.
# This also automatically updates /etc/named.d/forwarders.conf
sub write_local_forwarder {
    my $self = shift;

    y2milestone("Current dns forwarder: ".GetLocalForwarder());
    SCR->Write (".sysconfig.network.config.NETCONFIG_DNS_FORWARDER", GetLocalForwarder());
    SCR->Write (".sysconfig.network.config", undef);

    y2milestone("Updating forwarders by netconfig");
    my $ret = SCR->Execute (".target.bash_output", "/sbin/netconfig update -m dns");
    if ($ret->{'exit'} != 0) {
        Report->Error (__("Error occurred while calling netconfig.\nError: ".$ret->{'stdout'}));
    }
}

sub update_forwarding {
    # Netconfig updates /etc/named.d/forwarders.conf only if 'bind' is selected
    # as resolver. Manual writing of forwarders.conf is otherwise requested to be
    # done by Yast.
    #
    # Cheating netconfig by using local 'bind' as resolver temporarily to generate
    # correct /etc/named.d/forwarders.conf and then returning back to user-defined
    # resolver.
    #
    # This behavior including requested manual changes is described in FATE#309036

    my $self = shift;
    my $current_forwarder = $self->GetLocalForwarder();

    if ($current_forwarder ne 'bind') {
        y2milestone(
            "User-defined forwarder: ".$current_forwarder.", using 'bind' for a while to update forwarders.conf"
        );
        $self->SetLocalForwarder('bind');

        $self->write_local_forwarder();

        y2milestone("Returning back to user-defined forwarder: ".$current_forwarder);
        $self->SetLocalForwarder($current_forwarder);
    }

    $self->write_local_forwarder();
}

# Server package should be installed already, but we have to check, e.g.,
# when applying configuration in AutoYast config module
sub check_and_install_package {
    my $self = shift;
    return 1 if (PackageSystem->Installed("bind"));

    # Package cannot be installed in some modes, changing the mode temporarily
    my $previous_mode = Mode->mode();
    Mode->SetMode("normal");
    my $installed = PackageSystem->CheckAndInstallPackagesInteractive(["bind"]);

    # Reread the configuration stat if it has changed
    $configuration_timestamp = $self->GetConfigurationStat() if $installed;
    Mode->SetMode($previous_mode);

    return 1 if $installed;

    y2error("Server package cannot be installed, cannot write configuration");
    return 0;
}

BEGIN { $TYPEINFO{Write} = ["function", "boolean"]; }
sub Write {
    my $self = shift;

    # DNS server read dialog caption
    my $caption = __("Saving DNS Server Configuration");

    Progress->New( $caption, " ", 7, [
	# progress stage
	__("Flush caches of the DNS daemon"),
	# progress stage
	__("Save configuration files"),
	# progress stage
	__("Restart the DNS daemon"),
	# progress stage
	__("Update zone files"),
	# progress stage
	__("Adjust the DNS service"),
	# progress stage
	__("Call netconfig"),
	# progress stage
	__("Write the firewall settings")
    ],
    [
	# progress step
	__("Flushing caches of the DNS daemon..."),
	# progress step
	__("Saving configuration files..."),
	# progress step
	__("Restarting the DNS daemon..."),
	# progress step
	__("Updating zone files..."),
	# progress step
	__("Adjusting the DNS service..."),
	# progress step
	__("Calling netconfig..."),
	# progress step
	__("Writing the firewall settings..."),
	# progress step
	__("Finished")
    ],
    ""
    );

    Progress->NextStage ();

    return 0 unless $self->check_and_install_package();

    my $ok = 1;

    foreach my $z (@zones) {
	if (defined $z->{"modified"} and $z->{"modified"} == 1) {
	    y2milestone ("Some zones were modified");
	    $self->SetModified();
	    last;
	}
    }

    if ((! $modified) && (! SuSEFirewall->GetModified()))
    {
	return $ok;
    }

    # Reloading the service at the end
    # $ok = $self->StopDnsService () && $ok;

    Progress->NextStage ();

    # authenticate to LDAP 
    if ($use_ldap)
    {
	unless (LdapPrepareToWrite ()) {
	    y2error ("Cannot write to LDAP");
	    return 0;
	}
    }

    # Make sure the includes dir really exists
    SCR->Execute(".target.bash", "mkdir -pv '".String->Quote($includes_dir)."'");

    foreach my $z (@zones) {

	if (defined $z->{"connected_with"} && $z->{"connected_with"} ne "") {
	    $reverse_zones_connections_data{$z->{"zone"}} = $z->{"connected_with"};
	    # info: zone records might get rewritten
	    DnsServerHelperFunctions->RegenerateReverseZoneFrom ($z->{"zone"}, $z->{"connected_with"});
	} else {
	    delete $reverse_zones_connections_data{$z->{"zone"}};
	}
    }
    my $write_to = Directory->vardir()."/".$reverse_zones_connections;
    SCR->Write (".target.ycp", $write_to, \%reverse_zones_connections_data);

    ### Bugzilla #46121, Configuration file changed by hand, INI-Agent would break
    my $new_configuration_timestamp = $self->GetConfigurationStat();
    my $yast2_suffix = ".yast2-save";

    # timestamp differs from the Read()
    if (defined $configuration_timestamp
        and defined $new_configuration_timestamp
        and $configuration_timestamp ne $new_configuration_timestamp
    ) {
	y2warning("Stat of the configuration file was changed during the YaST2 configuration");
	# moving into yast2-save file
	my $ret = SCR->Execute (".target.bash_output", "mv --force ".$configfile." ".$configfile.$yast2_suffix);
	if ($ret->{'exit'} == 0) {
	    y2milestone("Configuration moved from '".$configfile."' to '".$configfile.$yast2_suffix);
	} else {
	    y2warning("Configuration cannot be moved from '".$configfile."' to '".$configfile.$yast2_suffix.": ".$ret->{'stderr'});
	    # removing the current file from disk
	    my $ret = SCR->Execute (".target.bash_output", "rm --force ".$configfile);
	    if ($ret->{'exit'} == 0) {
		y2milestone("Configuration file removed '".$configfile."'");
	    } else {
		y2milestone("Configuration cannot be removed '".$configfile."', configuration could demage during writing.");
	    }
	}
	my $create = SCR->Execute (".target.bash", "touch ".$configfile);
	y2milestone("Creating blank configuration file '".$configfile."'");
    }

    # save ACLs
    $ok = SCR->Write (".dns.named.value.acl", \@acl) && $ok;

    #save globals
    $ok = $self->SaveGlobals () && $ok;

    #adapt included files
    $ok = $self->AdaptDDNS () && $ok;

    #ensure that if there is an include file, named.conf.include gets recreated
    $ok = $self->EnsureNamedConfIncludeIsRecreated () && $ok;

    #set daemon starting
    SCR->Write (".sysconfig.named.NAMED_RUN_CHROOTED", $chroot ? "yes" : "no");
    SCR->Write (".sysconfig.named", undef);

    # Store the NETCONFIG_DNS_POLICY 
    # Note: NETCONFIG_DNS_STATIC_SERVERS is stored in SaveGlobals();
    SCR->Write (".sysconfig.network.config.NETCONFIG_DNS_POLICY", $netconfig_dns_policy);

    # set to sysconfig if LDAP is to be used
    # set the sysconfig also if LDAP is not to be used (bug #165189)
    LdapStore ();

    Progress->NextStage ();

    #save all zones
    @zones_update_actions = ();

    foreach my $z (@zones) {
	$ok = $self->ZoneWrite ($z) && $ok;
    }

    # Flush the cache after writing zones, but before re/starting service
    # (otherwise new zones aren't written before closing Yast)
    SCR->Write (".dns.named", undef);

    my $ret = 1;
    if (scalar (@zones_update_actions) > 0)
    {
	# named is running
	if (Service->Status("named") == 0) {
	    $ret = Service->Reload("named");
	}
    }

    Progress->NextStage ();

    if (scalar (@zones_update_actions) > 0)
    {
	if (! $ret)
	{
	    $ok = 0;
	}
	else
	{
	    DnsZones->UpdateZones (\@zones_update_actions);
	}
    }

    Progress->NextStage ();

    $ret = {};

    my $user_defined_forwarder = GetLocalForwarder();

    # Write forwarding settings before starting 'named'
    $self->update_forwarding();

    $ret = {};
    # named has to be started
    if ($start_service)
    {
	my $success = 1;
	if (! $write_only)
	{
	    # named is running
	    if (Service->Status("named") == 0) {
		y2milestone("Reloading service 'named'");
		$success = Service->Reload("named")
	    } else {
		y2milestone("Restarting service 'named'");
		$success = Service->Restart("named")
	    }
	}
	Service->Enable ("named");
	if (! $success)
	{
	    # Cannot start service 'named', because of error that follows Error:.  Do not translate named.
	    Report->Error (__("Error occurred while starting service named.\n\n"));
	    $ok = 0;
	    # There's no 'named' running -> prevent from blocking DNS queries
	    $self->SetLocalForwarder("resolver") if GetLocalForwarder() eq "bind";
	    y2warning("Local forwarder set to: ".GetLocalForwarder());
	}
    }
    # named has to be stopped
    else
    {
	if (! $write_only)
	{
	    y2milestone("Stopping service 'named'");
	    Service->Stop("named");
	    # There's no 'named' running. Reset dns forwarder again
	    $self->SetLocalForwarder("resolver") if GetLocalForwarder() eq "bind";
	    y2warning("Local forwarder set to: ".GetLocalForwarder());
	}
	Service->Disable ("named");
    }

    # First run finished
    if ($ok and first_run())
    {
	SCR->Write (".target.string", $data_file, "");
    }
    
    Progress->NextStage ();

    # local forwarder has been changed because 'named' was unable to start
    # or it was disabled by user
    if ($user_defined_forwarder ne GetLocalForwarder()) {
        y2milestone ("NETCONFIG_DNS_FORWARDER has been changed from ".$user_defined_forwarder." to ".GetLocalForwarder());
        $self->write_local_forwarder();
    }

    Progress->NextStage ();

    # Firewall has it's own Progress
    my $progress_orig = Progress->set (0);
    SuSEFirewall::Write();
    Progress->set ($progress_orig);

    Progress->NextStage ();

    return $ok;
}

BEGIN { $TYPEINFO{Export}  =["function", [ "map", "any", "any" ] ]; }
sub Export {
    my $self = shift;

    if (not defined $start_service || $start_service !~ /^[01]$/) {
	y2warning("start_service = '".$start_service."'");
    }
    if (not defined $chroot || $chroot !~ /^[01]$/) {
	y2warning("chroot = '".$chroot."'");
    }

    my %ret = (
	"start_service" => $start_service,
	"chroot" => $chroot,
	"use_ldap" => $use_ldap,
	"allowed_interfaces" => \@allowed_interfaces,
	"zones" => \@zones,
	"options" => \@options,
	"logging" => \@logging,
    );
    return \%ret;
}
BEGIN { $TYPEINFO{Import} = ["function", "boolean", [ "map", "any", "any" ] ]; }
sub Import {
    my $self = shift;
    my %settings = %{+shift};

    # Cache the timestamp as done in Read() otherwise the named.conf
    # is re-created from scratch in Write() as is pretends to be changed
    # while Yast was running.
    $configuration_timestamp = $self->GetConfigurationStat();

    $start_service = $settings{"start_service"} || 0;
    $chroot = $settings{"chroot"} || 1;
    $use_ldap = $settings{"use_ldap"} || 0;
    @allowed_interfaces = @{$settings{"allowed_interfaces"} || []};

    @zones = @{$settings{"zones"} || []};
    for my $zone (@zones) {
      $zone->{"modified"} = 1;
      # Local zones are already part of the 'bind' package
      $zone->{"is_new"} = 1 unless is_system_zone($zone->{"zone"});
      y2milestone("Imported zone: ".$zone->{"zone"});
    }

    @options = @{$settings{"options"} || []};
    @logging = @{$settings{"logging"} || []};

    $modified = 1;
    $save_all = 1;
    @files_to_delete = ();
    %current_zone = ();
    $current_zone_index = -1;
    $write_only = 0;

    if (Mode->autoinst() && $use_ldap)
    {
	# Initialize LDAP if needed
	$self->InitYapiConfigOptions ({"use_ldap" => $use_ldap});
	$self->LdapInit (0, 0);
	$self->CleanYapiConfigOptions ();
    }

    return 1;
}

BEGIN { $TYPEINFO{Summary} = ["function", [ "list", "string" ] ]; }
sub Summary {
    my $self = shift;

    my %zone_types = (
	# type of zone to be used in summary
	"master" => __("Master"),
	# type of zone to be used in summary
	"slave" => __("Slave"),
	# type of zone to be used in summary
	"stub" => __("Stub"),
	# type of zone to be used in summary
	"hint" => __("Hint"),
	# type of zone to be used in summary
	"forward" => __("Forward"),
    );
    my @ret = ();

    if ($start_service)
    {
	# summary string
	push (@ret, __("The DNS server starts when booting the system."));
    }
    else
    {
	push (@ret,
	    # summary string
	    __("The DNS server does not start when booting the system."));
    }

    my @zones_descr = map {
	my %zone_map = %{$_};
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

    my $zones_list = join (",<br>\n", @zones_descr);
    #  summary string, %s is list of DNS zones (their names), coma separated
    push (@ret, sprintf (__("Configured Zones: %s"), $zones_list));
    return \@ret;
}

BEGIN { $TYPEINFO{LdapInit} = ["function", "boolean", "boolean", "boolean" ]; }
sub LdapInit {
    my $self = shift;
    my $ask_user_to_enable_ldap	= shift || 0;
    my $report_errors		= shift || 0;

    $ldap_available = 0;
    $use_ldap = 0;

    #error message
    my $ldap_error_msg = __("Invalid LDAP configuration. Cannot use LDAP.");

    if (Mode->test ())
    {
	return;
    }

    y2milestone ("Initializing LDAP support");

    # grab info about the LDAP server
    if (!Mode->autoinst() && !Mode->config()) {
	Ldap->Read ();
    }
    my $ldap_data_ref = Ldap->Export ();

    my $server = $ldap_data_ref->{"ldap_server"};
    if (! defined ($server))
    {
	$server = "";
    }
    my @server_port = split /:/, $server;
    $server = $server_port[0] || "";
    my $port = $server_port[1] || "389";

    if ($server eq "")
    {
	$use_ldap = 0;
	y2milestone ("LDAP not configured - can't find server");
	if ($report_errors)
	{
	    Report->Error ($ldap_error_msg);
	}
	return;
    }
    y2milestone("Trying LDAP server: ".$server.":".$port);
    
    $ldap_domain = $ldap_data_ref->{"ldap_domain"} || "";
    if ($ldap_domain eq "")
    {
	$use_ldap = 0;
	y2milestone ("LDAP not configured - can't read LDAP domain");
	if ($report_errors)
	{
	    Report->Error ($ldap_error_msg);
	}
	return;
    }
    y2milestone("Trying LDAP domain: ".$ldap_domain);

    $ldap_server = $server;
    $ldap_port = $port;

    # get main configuration DN
    $ldap_config_dn = Ldap->GetMainConfigDN ();
    y2milestone ("Main configuration DN: $ldap_config_dn");
    if (! defined ($ldap_config_dn) || $ldap_config_dn eq "")
    {
	$use_ldap = 0;
	y2milestone ("Main config DN not found");
	if ($report_errors)
	{
	    Report->Error ($ldap_error_msg);
	}
	return;
    }

    $ldap_available = 1;

    if (defined $yapi_conf{"use_ldap"})
    {
	$use_ldap = $yapi_conf{"use_ldap"};
	y2milestone ("YaPI sepcified to use LDAP: $use_ldap");
    }
    else
    {
	my $reload_script = SCR->Read (".sysconfig.named.NAMED_INITIALIZE_SCRIPTS") || "";
	if (! $reload_script || $reload_script !~ /.*ldapdump.*/)
	{
	    # don't ask user in the read dialog
	    if ($ask_user_to_enable_ldap) {
		# yes-no popup
		$use_ldap = Popup->YesNo (__("Enable LDAP support?"));
		$self->UseLdapModified();
		y2milestone ("User chose to use LDAP: $use_ldap");
	    # just disable LDAP
	    } else {
		$use_ldap = 0;
	    }
	}
	else
	{
	    # ldapdump script in /etc/sysconfig/named/NAMED_INITIALIZE_SCRIPTS means use-LDAP
	    $use_ldap = $reload_script =~ /.*ldapdump.*/;
	    y2milestone ("Use LDAP according to sysconfig: $use_ldap");
	}
    }

    if (! $use_ldap)
    {
	y2milestone ("Not using LDAP");
	return;
    }

    # connect to the LDAP server
    my %ldap_init = (
	"hostname" => $server,
	"port" => $port,
    );
    my $ret = SCR->Execute (".ldap", \%ldap_init);
    if ($ret == 0)
    {
	$use_ldap = 0;
	Ldap->LDAPErrorMessage ("init", Ldap->LDAPError ());
	return;
    }

    $ret = SCR->Execute (".ldap.bind", {});
    if ($ret == 0)
    {
	$use_ldap = 0;
	Ldap->LDAPErrorMessage ("bind", Ldap->LDAPError ());
	return;
    }



    # find suseDnsConfiguration object
    my %ldap_query = (
        "base_dn" => $ldap_config_dn,
        "scope" => 2,   # top level only
        "map" => 1,     # gimme a list (single entry)
	"filter" => "(objectclass=suseDnsConfiguration)",
    );

    my $found_ref = SCR->Read (".ldap.search", \%ldap_query);
    my %found = %{ $found_ref || {} };
    if (scalar (keys (%found)) == 0)
    {
	%found = (
	    'objectclass' => [ 'top', 'suseDnsConfiguration' ],
	    'cn' => [ 'defaultDNS' ],
	    'suseDefaultBase' => [ 'ou=DNS,'.$ldap_domain ],
	);
    }
    else
    {
	my @keys = sort (keys (%found));
	my $dns_conf_dn = $keys[0];
	%found = %{$found{$dns_conf_dn}}
    }

    # check if base DN for zones is defined
    my @bases = @{ $found{"suseDefaultBase"} || [] };
    if (@bases == 0)
    {
	@bases = ("ou=DNS,$ldap_domain");
    }
    my $zone_base_config_dn = $bases[0];

    y2milestone ("Base config DN: $zone_base_config_dn");
    DnsZones->SetZoneBaseConfigDn ($zone_base_config_dn);

    # Check perl-ldap package (required for syncing LDAP to zone files)
    if (! (Mode->config () || Package->Installed ("perl-ldap")))
    {
	my $installed = Package->Install ("perl-ldap");
	if (! $installed)
	{
	    # error popup
	    Report->Error (__("Installation of required packages failed.
LDAP support will not be active."));

	    $use_ldap = 0;
	    return;
	}
    }

    # finalize the function
    y2milestone ("Running in the LDAP mode");
    $use_ldap = 1;
    return;
}

# Checks whether all required schemas are correctly included
# Gets an LDAP Domain as a parameter
# Returns boolean
sub LdapSchemasPresent ($) {
    my $ldap_domain = shift;
    my $ret = 1;
    local $Data::Dumper::Indent = 0;

    my $dns_zone = "ou=DNS,".$ldap_domain;
    my $dz_ret = Ldap->GetLDAPEntry ($dns_zone);
    y2milestone ("LDAP: DNS (".$dns_zone.") found: ".Dumper($dz_ret));

    # Record not found
    $ret = 0 if (! defined $dz_ret || keys(%{$dz_ret}) == 0);

    return $ret;
}

BEGIN { $TYPEINFO{LdapPrepareToWrite} = ["function", "boolean"];}
sub LdapPrepareToWrite {
    my $self = shift;

    my %ldap_query = ();
    my $found_ref = 0;
    my $zone_base_config_dn = DnsZones->GetZoneBaseConfigDn ();

    # check if the schema is properly included
    NetworkInterfaces->Read ();
    if ($ldap_server =~ /^127\.0\.0\.[0-9]+$/ || $ldap_server eq "localhost" || $ldap_server eq "::1"
	|| -1 != index (lc ($ldap_server), lc (Hostname->CurrentHostname()))
	|| 0 != scalar (@{NetworkInterfaces->Locate ("IPADDR", $ldap_server)}))
    {
	y2milestone ("LDAP server is local, checking included schemas");
	LdapServerAccess->AddLdapSchemas(
	    ["/etc/openldap/schema/yast.schema", "/etc/openldap/schema/dnszone.schema"],1
	);
    }
    else
    {
	y2milestone ("LDAP server is remote, not checking if schemas are properly included");
    }

    # connect to the LDAP server
    my $ret = Ldap->LDAPInit ();
    # BNC #679960
    $ret = _("Unknown LDAP initialization error.") unless (defined $ret);

    if ($ret ne "")
    {
	Ldap->LDAPErrorMessage ("init", $ret);
	return 0;
    }

    # login to the LDAP server
    if (defined ($yapi_conf{"ldap_passwd"}))
    {
	my $err = Ldap->LDAPBind ($yapi_conf{"ldap_passwd"});
	Ldap->SetBindPassword ($yapi_conf{"ldap_passwd"});
	if ($err ne "")
	{
	    Ldap->LDAPErrorMessage ("bind", $err);
	    return 0;
	}
    }
    else
    {
	my $auth_ret = Ldap->LDAPAskAndBind (0);
	Ldap->SetBindPassword ($auth_ret);

	if (! defined ($auth_ret) || $auth_ret eq "")
	{
	    y2milestone ("Authentication canceled");
	    return;
	}
    }

    Ldap->SetGUI(YaST::YCP::Boolean(0)); 
    if(! Ldap->CheckBaseConfig($ldap_config_dn))
    { 
	Ldap->SetGUI(YaST::YCP::Boolean(1));
	# TRANSLATORS: Popup error message, %1 is an LDAP object whose creation failed
	Report->Error (sformat (__("Error occurred while creating %1."),
	    $ldap_config_dn));
    } 
    Ldap->SetGUI(YaST::YCP::Boolean(1)); 

    # If non-local server is used, schemas are not handled but required anyway
    # BNC #710430 and BNC #690237
    # Currently just for logging purpose here
    LdapSchemasPresent($ldap_domain);

    # find suseDnsConfiguration object
    %ldap_query = (
        "base_dn" => $ldap_config_dn,
        "scope" => 2,   # top level only
        "map" => 1,     # gimme a list (single entry)
	"filter" => "(objectclass=suseDnsConfiguration)",
	"not_found_ok" => 1,
    );

    $found_ref = SCR->Read (".ldap.search", \%ldap_query);
    my %found = %{ $found_ref || {} };
    if (scalar (keys (%found)) == 0)
    {
	y2milestone ("No DNS configuration found in LDAP, creating it");
	my %ldap_object = (
	    'objectclass' => [ 'top', 'suseDnsConfiguration' ],
	    'cn' => [ 'defaultDNS' ],
	    'suseDefaultBase' => [ 'ou=DNS,'.$ldap_domain ],
	);
	my %ldap_request = (
	    "dn" => "cn=defaultDNS,$ldap_config_dn",
	);
	my $result = SCR->Write (".ldap.add", \%ldap_request, \%ldap_object);
	if (! $result)
	{
	    # error report, %1 is ldap object
	    Report->Error (sformat (__("Error occurred while creating cn=defaultDNS,%1. Not using LDAP."), $ldap_config_dn));
	    my $err = SCR->Read (".ldap.error") || {};
	    my $err_descr = Dumper ($err);
	    y2error ("Error descr: $err_descr");
	    return 0;
	}
	%found = %ldap_object;
    }
    else
    {
	my @keys = sort (keys (%found));
	my $dns_conf_dn = $keys[0];
	%found = %{$found{$dns_conf_dn}};
	# check if base DN for zones is defined
	my @bases = @{ $found{"suseDefaultBase"} || [] };
	if (@bases == 0)
	{
	    my %ldap_object = %found;
	    $ldap_object{"suseDefaultBase"} = ["ou=DNS,$ldap_domain"];
	    my %ldap_request = (
		"dn" => "$dns_conf_dn",
	    );
	    my $result = SCR->Write (".ldap.modify", \%ldap_request, \%ldap_object);
	    if (! $result)
	    {
		# error report, %1 is LDAP record DN
		Report->Error (sformat (__("Error occurred while updating %1."), $dns_conf_dn));
		my $err = SCR->Read (".ldap.error") || {};
		my $err_descr = Dumper ($err);
		y2error ("Error descr: $err_descr");
		return 0;
	    }
	    @bases = ("ou=DNS,$ldap_domain");
	}
    }

    # check existence of base DN for zones
    %ldap_query = (
        "base_dn" => $zone_base_config_dn,
        "scope" => 0,   # top level only
        "map" => 0,     # gimme a list (single entry)
	"not_found_ok" => 1,
    );
    $found_ref = SCR->Read (".ldap.search", \%ldap_query);
    my @found = @{ $found_ref || [] };
    if (@found == 0)
    {
	$zone_base_config_dn =~ m/^ou=([^,]+),.*/;
	my $ou = $1;
	my %ldap_object = (
            'objectclass' => [ 'top', 'organizationalUnit' ],
            'ou' => [ $ou ],
	);
	my %ldap_request = (
	    "dn" => $zone_base_config_dn,
	);

	my $result = SCR->Write (".ldap.add", \%ldap_request, \%ldap_object);
	if (! $result)
	{
	    # error report, %1 is LDAP record DN
	    Report->Error (sformat (__("Error occurred while creating %1. Not using LDAP."), $zone_base_config_dn));
	    my $err = SCR->Read (".ldap.error") || {};
	    my $err_descr = Dumper ($err);
	    y2error ("Error descr: $err_descr");
	    return 0;
	}
    }

    return 1;
}

BEGIN { $TYPEINFO{LdapStore} = ["function", "void" ]; }
sub LdapStore {
    my $self = shift;

    my $reload_script = SCR->Read (".sysconfig.named.NAMED_INITIALIZE_SCRIPTS") || "";
    my @reload_scripts = split / /, ((defined $reload_script) ? $reload_script:"");

    if ($use_ldap)
    {
	y2milestone("LdapStore: using ldap");
	my $already_present = scalar (grep (/ldapdump/, @reload_scripts)) > 0;
	if (! $already_present)
	{
	    push @reload_scripts, "ldapdump";
	}
    }
    else
    {
	y2milestone("LdapStore: not using ldap");
	@reload_scripts = grep (!/ldapdump/, @reload_scripts);
    }

    $reload_script = join (" ", @reload_scripts);
    y2milestone("Writing reload scripts: '".$reload_script."'");
    SCR->Write (".sysconfig.named.NAMED_INITIALIZE_SCRIPTS", $reload_script);
    SCR->Write (".sysconfig.named", undef);
}

BEGIN{$TYPEINFO{EnsureNamedConfIncludeIsRecreated} = ["function", "boolean"];}
sub EnsureNamedConfIncludeIsRecreated {
    my $self = shift;

#    my $includes = SCR->Read (".sysconfig.named.NAMED_CONF_INCLUDE_FILES");
#    if ($includes eq "")
#    {
#	return 1;
#    }

    my $reload_script = SCR->Read (".sysconfig.named.NAMED_INITIALIZE_SCRIPTS") || "";
    my @reload_scripts = split / /, ((defined $reload_script) ? $reload_script:"");

    my $already_present
	= scalar (grep (/createNamedConfInclude/, @reload_scripts)) > 0;
    if (! $already_present)
    {
	unshift @reload_scripts, "createNamedConfInclude";
    }

    $reload_script = join (" ", @reload_scripts);
    SCR->Write (".sysconfig.named.NAMED_INITIALIZE_SCRIPTS", $reload_script);
    SCR->Write (".sysconfig.named", undef);

    return 1;
}

# initialize options passed through the YaPI
BEGIN { $TYPEINFO{InitYapiConfigOptions} = ["function", "void", ["map", "string", "any"]]; }
sub InitYapiConfigOptions {
    my $self = shift;
    my $config_ref = shift;

    %yapi_conf = %{$config_ref || {}};
}

BEGIN { $TYPEINFO{CleanYapiConfigOptions} = ["function", "void"]; }
sub CleanYapiConfigOptions {
    my $self = shift;

    %yapi_conf = ();
}

# -1 == not defined
#  1 == yes
#  0 == no
my $expert_ui = -1;

BEGIN { $TYPEINFO{ExpertUI} = ["function", "boolean"]; };
sub ExpertUI () {
    if ($expert_ui != -1) {
	return $expert_ui;
    }

    # simple == 0
    # expert (or default) == 1
    # $expert_ui = (ProductFeatures->GetFeature ("globals", "ui_mode") eq "simple" ? 0 : 1);
    $expert_ui = 1;
    return $expert_ui;
}

BEGIN { $TYPEINFO{first_run} = ["function", "boolean"]; };
sub first_run () {
    return ! FileUtils->Exists($data_file);
}

1;

# EOF
