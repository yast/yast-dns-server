##
# File:		DnsServerAPI.pm
# Package:	Configuration of dns-server
# Summary:	Global functions for dns-server configurations.
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# Functions for dns-server configuration divided by logic sections
# of the configuration file.
##

###                                                                     ###
#                                                                         #
# Note: this version is under development. It is a functional extension   #
# for the previous non-functional version. It is not backward-compatible. #
#                                                                         #
###                                                                     ###

package DnsServerAPI;

use strict;
use YaPI;
textdomain("dns-server");

use YaST::YCP qw( sformat );
YaST::YCP::Import ("DnsServer");
YaST::YCP::Import ("Service");
YaST::YCP::Import ("Progress");
# for reporting errors
YaST::YCP::Import ("Report");
# for syntax checking
YaST::YCP::Import ("IP");
# for syntax checking
YaST::YCP::Import ("Hostname");

our %TYPEINFO;

my $SETTINGS = {
    'logging_channel_file' => 'log_file',
    'logging_channel_syslog' => 'log_syslog',
};

# FIXME: makes sense for SLES
my $OPTIONS = {
    'version' => {
	'type' => 'quoted-string',
	'record' => 'single',
    },
};

# LOCAL FUNCTIONS >>>

# Function returns list of strings created from BIND option '{ ... }';
# '{ a; b; c; }' -> ['a', 'b', 'c']
sub GetListFromRecord {
    my $record = shift;
    $record =~ s/(^[\t ]*\{[\t ]*|[\t ]*\}[\t ]*$)//g;
    $record =~ s/( +|;$)//g;

    return split(';', $record);
}

# Function returns BIND record created from list of strings
# ['a', 'b', 'c'] -> '{ a; b; c; }'
sub GetRecordFromList {
    my @records = @_;

    if (scalar(@records)>0) {
	return '{ '.join('; ', @records).'; }';
    } else {
	return '{ }';
    }
}

# Function returns sorted set of list
# ['a','c','a','b'] -> ['a','b','c']
sub ToSet {
    my @list = @_;
    my $map  = {};
    foreach (@list) {
	$map->{$_} = $_;
    }
    @list = ();
    foreach (sort {$a cmp $b} (keys(%{$map}))) {
	push @list, $_;
    }
    return @list;
}

# Function checks if the 1st parameter is a valid IPv4
# If not, opens error popup and returns false
sub CheckIPv4 {
    my $class = shift;
    my $ipv4  = shift || '';

    if (!IP->Check4($ipv4)) {
	# TRANSLATORS: Popup error message during parameters validation, %1 is a string which is needed to be an IPv4
	Report->Error(sformat(__("String '%1' is not valid IPv4 address."), $ipv4)."\n\n".IP->Valid4());
	return 0;
    }
    
    return 1;
}

sub CheckZone {
    my $class = shift;
    my $zone  = shift || '';

    if (!$zone) {
	# TRANSLATORS: Popup error message, Calling function which needs DNS zone name defined
	Report->Error(__("Zone name must be defined."));
	return 0;
    }

    my $zones = $class->GetZones();
    foreach my $known_zone (keys %{$zones}) {
	return 1 if ($zone eq $known_zone);
    }
    
    # TRANSLATORS: Popup error message, Trying to get information from zone which doesn't exist, %1 is the zone name
    Report->Error(sformat(__("DNS zone '%1' does not exist."), $zone));
    return 0;
}

sub CheckZoneType {
    my $class = shift;
    my $type  = shift || '';

    if (!$type) {
	# TRANSLATORS: Popup error message, Calling function which needs DNS zone type defined
	Report->Error(__("Zone type must be defined."));
	return 0;
    }

    if ($type !~ /^(master|slave)$/) {
	# TRANSLATORS: Popup error message, Calling function with unsupported DNZ zone type, %1 is the zone type
	Report->Error(sformat(__("Zone type '%1' is not supported."), $type));
	return 0;
    }

    return 1;
}

sub CheckTransportACL {
    my $class = shift;
    my $acl   = shift || '';

    if (!$acl) {
	# TRANSLATORS: Popup error message, Calling function which needs ACL name defined
	Report->Error(__("ACL name must be defined."));
	return 0;
    }

    my $acls = $class->GetACLs();
    foreach my $known_acl (keys %{$acls}) {
	return 1 if ($acl eq $known_acl);
    }

    # TRANSLATORS:  Popup error message, Calling function with unknown ACL, %1 is the ACL's name
    Report->Error(sformat(__("ACL named '%1' does not exist."), $acl));
    return 0;
}

sub CheckHostname {
    my $class = shift;
    my $hostname = shift || '';

    if (!$hostname) {
	# TRANSLATORS:  Popup error message, Calling function with undefined parameter
	Report->Error(__("Hostname must be defined."));
	return 0;
    }

    # FQDN
    if ($hostname =~ /\./) {
	# DNS FQDN must be finished with a dot
	if ($hostname =~ s/\.$//) {
	    if(Hostname->CheckFQ($hostname)) {
		return 1;
	    } else {
		# Popup error message, wrong FQDN format
		Report->Error(__("Wrong format of fully qualified hostname."));
		return 0;
	    }
	# DNS FQDN which doesn't finish with a dot!
	} else {
	    # Popup error message, FQDN hostname must finish with a dot
	    Report->Error(__("Fully qualified hostname must be finished with a dot."));
	    return 0;
	}
    # Relative name
    } else {
	if (Hostname->Check($hostname)) {
	    return 1;
	} else {
	    # TRANSLATORS: Popup error message, wrong hostname, allowed syntax is described two lines below using a pre-defined text
	    Report->Error(__("Wrong format of hostname.")."\n\n".Hostname->ValidHost());
	    return 0;
	}
    }
}

sub CheckMXPriority {
    my $class = shift;
    my $prio  = shift || '';

    if (!$prio) {
	# TRANSLATORS: Popup error message, Checking parameters, MX priority is a needed parameter
	Report->Error(__("Mail exchange priority must be defined."));
	return 0;
    }

    if ($prio !~ /^[\d]+$/ || ($prio<0 && $prio>65535)) {
	# TRANSLATORS: Popup error message, Checking parameters, wrong format
	Report->Error(__("Wrong mail exchange priority.
It must be a number between 0 and 65535 included."));
	return 0;
    }
}

sub CheckResourceRecord {
    my $class  = shift;
    my $record = shift;

    foreach my $key ('type', 'key', 'value') {
	$record->{$key} = '' if (not defined $record->{$key});
    }
    $record->{'type'} = uc($record->{'type'});

    if (!$record->{'type'}) {
	return 0;
    }

    if ($record->{'type'} eq 'A') {
	return 0 if (!$class->CheckHostname($record->{'key'}));
	return 0 if (!$class->CheckIPv4($record->{'value'}));
	return 1;
    } elsif ($record->{'type'} eq 'CNAME') {
	return 0 if (!$class->CheckHostname($record->{'key'}));
	return 0 if (!$class->CheckHostname($record->{'value'}));
	return 1;
    } elsif ($record->{'type'} eq 'PTR') {
	return 0 if (!$class->CheckIPv4($record->{'key'}));
	return 0 if (!$class->CheckHostname($record->{'value'}));
	return 1;
    } elsif ($record->{'type'} eq 'NS') {
	return 0 if (!$class->CheckHostname($record->{'key'}));
	return 0 if (!$class->CheckHostname($record->{'value'}));
	return 1;
    } elsif ($record->{'type'} eq 'MX') {
	return 0 if (!$class->CheckHostname($record->{'key'}));
	if ($record->{'value'} =~ /^[\t ]*([^\t ]+)[\t ]+(.*)$/) {
	    return 0 if (!$class->CheckHostname($1));
	    return 0 if (!$class->CheckMXPriority($2));
	    return 1;
	} else {
	    # Popup error message, Checking MX (Mail eXchange) record format
	    Report->Error(__("Wrong MX record format.
Use 'priority server-name'."));
	    return 0;
	}
    }

    y2warning("Undefined record type '".$record->{'type'}."'");
    return 1;
}

# Function returns quoted string by a double-quote >>"<<
# 'A"b"Cd42' -> '"A\"b\"Cd42"'
sub QuoteString {
    my $class = shift;
    
    my $string = shift;
    my $quote  = '"';

    $string =~ s/\\/\\\\/g;
    $string =~ s/$quote/\\$quote/g;
    $string = $quote.$string.$quote;

    return $string;
}

sub UnquoteString {
    my $class = shift;
    
    my $string = shift;
    my $quote  = '"';

    $string =~ s/^$quote//;
    $string =~ s/$quote$//;
    $string =~ s/\\$quote/$quote/g;
    $string =~ s/\\\\/\\/g;

    return $string;
}

# GLOBAL FUNCTIONS >>>

BEGIN{$TYPEINFO{StopDnsService} = ["function", "boolean", ["map", "string", "any"]];}
sub StopDnsService {
    my $self = shift;
    my $config_options = shift;
    return DnsServer->StopDnsService ();
}

BEGIN{$TYPEINFO{StartDnsService} = ["function", "boolean", ["map", "string", "any"]];}
sub StartDnsService {
    my $self = shift;
    my $config_options = shift;
    return DnsServer->StartDnsService ();
}

BEGIN{$TYPEINFO{GetDnsServiceStatus} = ["function", "boolean", ["map", "string", "any"]];}
sub GetDnsServiceStatus {
    my $self = shift;
    my $config_options = shift;
    return DnsServer->GetDnsServiceStatus ();
}

BEGIN{$TYPEINFO{Read} = ["function", "boolean"]};
sub Read {
    my $class = shift;
    
    my $progress_orig = Progress->set (0);
    my $ret = DnsServer->Read ();
    Progress->set ($progress_orig);

    return $ret;
}

BEGIN{$TYPEINFO{GetForwarders} = ["function", ["list", "string"]]};
sub GetForwarders {
    my $class = shift;

    my $options = DnsServer->GetGlobalOptions();
    my $forwarders = '';
    my @ret;
    foreach (@{$options}) {
	if ($_->{'key'} eq 'forwarders') {
	    $forwarders = $_->{'value'};
	    @ret = GetListFromRecord($_->{'value'});
	    last;
	}
    }

    return \@ret;
}

BEGIN{$TYPEINFO{AddForwarder} = ["function", "boolean", "string"]};
sub AddForwarder {
    my $class = shift;
    my $new_one = shift;

    return 0 if (!$class->CheckIPv4($new_one));

    my $forwarders = $class->GetForwarders();
    if (!DnsServer->contains($forwarders, $new_one)) {
	push @{$forwarders}, $new_one;

	my $options = DnsServer->GetGlobalOptions();
	my $current_record = 0;
	foreach (@{$options}) {
	    if ($_->{'key'} eq 'forwarders') {
		@{$options}[$current_record] = {
		    'key' => 'forwarders',
		    'value' => GetRecordFromList(@{$forwarders}),
		};
		last;
	    }
	    ++$current_record;
	}
	DnsServer->SetGlobalOptions($options);
	return 1;
    }

    return 1;
}

BEGIN{$TYPEINFO{RemoveForwarder} = ["function", "boolean", "string"]};
sub RemoveForwarder {
    my $class = shift;
    my $remove_this = shift;

    my $forwarders = $class->GetForwarders();
    if (grep { /^$remove_this$/ } @{$forwarders}) {
	@{$forwarders} = grep { $_ ne $remove_this } @{$forwarders};

	my $options = DnsServer->GetGlobalOptions();
	my $current_record = 0;
	foreach (@{$options}) {
	    if ($_->{'key'} eq 'forwarders') {
		@{$options}[$current_record] = {
		    'key' => 'forwarders',
		    'value' => GetRecordFromList(@{$forwarders}),
		};
		last;
	    }
	    ++$current_record;
	}
	DnsServer->SetGlobalOptions($options);
	return 1;
    }

    return 1;
}

BEGIN{$TYPEINFO{IsLoggingSupported} = ["function", "boolean"]};
sub IsLoggingSupported {
    my $class = shift;
    
    my $logging = DnsServer->GetLoggingOptions();
    # only one channel is supported
    my $number_of_channels = 0;
    # only one channel for one category is supported
    my $more_channels_at_once = 0;

    foreach (@{$logging}) {
	if ($_->{'key'} eq 'channel') {
	    ++$number_of_channels;
	} elsif ($_->{'key'} eq 'category') {
	    my $used_channels = $_->{'value'};
	    $used_channels =~ s/(^[\t ]*[^\t ]+[\t ]*\{[\t ]*|[\t ;]+\}[\t ]*$)//g;
	    my @count_of_channels_at_once = split(';',$used_channels);
	    if (scalar(@count_of_channels_at_once)>1) { $more_channels_at_once = 1; }
	}
    }

    if ($number_of_channels>1 || $more_channels_at_once!=0) {
	return 0;
    }
    return 1;
}

BEGIN{$TYPEINFO{GetLoggingChannel} = ["function", ["map", "string", "string"]]};
sub GetLoggingChannel {
    my $class = shift;

    my $logging_ret = {
	'destination' => '',
	'filename' => '',
	'size' => '0',
	'versions' => '0',
    };

    my $logging = DnsServer->GetLoggingOptions();
    foreach (@{$logging}) {
	if ($_->{'key'} eq 'channel') {
	    my $log_channel = $_->{'value'};
	    if ($log_channel =~ /\{[\t ]*syslog;[\t ]*\}/) {
		$logging_ret->{'destination'} = 'syslog';
		last;
	    } elsif ($log_channel =~ /\{[\t ]*file[\t ]*/ ) {
		$logging_ret->{'destination'} = 'file';
		# remove starting and ending brackets, spaces and channel name
		$log_channel =~ s/(^[^{]+\{[\t ]*|[\t ]*;[\t ]*\}.*$)//g;

		# to prevent from jammed system
		my $max_loop = 10;
		while ($max_loop>0 && $log_channel =~ s/((file)[\t ]+(\"(\\"|[^\"])*\")|(versions)[\t ]+([^\t ])+|(size)[\t ]+([^\t ]+))//) {
		    if ($2) {
			$logging_ret->{'filename'} = $class->UnquoteString($3);
		    } elsif ($5) {
			$logging_ret->{'versions'} = $6;
		    } elsif ($7) {
			$logging_ret->{'size'} = $8;
		    }
		    --$max_loop;
		}
		last;
	    }
	}
    }

    return $logging_ret;
}

BEGIN{$TYPEINFO{SetLoggingChannel} = ["function", "boolean", ["map", "string", "string"]]};
sub SetLoggingChannel {
    my $class = shift;
    my $channel = shift;

#   $channel_params = {
#	'destination' => '', (file|syslog)
#	'filename' => '',    (filename,   needed for 'file')
#	'size' => '0',       (any string, needed for 'file')
#	'versions' => '0',   (any string, needed for 'file')
#   };

    # checking destination
    if (not defined $channel->{'destination'} || $channel->{'destination'} !~ /^(file|syslog)$/) {
	y2error("'destination' must be 'file' or 'syslog'");
	return 0;
    }
    # checking logfile settings
    if ($channel->{'destination'} eq 'file') {
	if (not defined $channel->{'filename'} || $channel->{'filename'} eq '') {
	    # TRANSLATORS: Popup error message, parameters validation, 'filename' is needed parameter
	    Report->Error(__("Filename must be defined while logging destination is file."));
	    return 0;
	}
	# checking logfile size
	if (not defined $channel->{'size'}) {
	    $channel->{'size'} = 0;
	} elsif ($channel->{'size'} !~ /^\d+[kKmMgG]?$/) {
	    # TRANSLATORS: Popup error message, parameters validation, wrongly set file size
	    Report->Error(__("Wrong file size format.

It must be set in format 'number[suffix]'\n
Possible suffixes are 'k', 'K', 'm', 'M', 'g' or 'G'."));
	    return 0;
	}
	# checking logfile versions
	if (not defined $channel->{'versions'}) {
	    $channel->{'versions'} = 0;
	} elsif ($channel->{'versions'} !~ /^\d+$/) {
	    # TRANSLATORS: Popup error message, parameters validation, wrongly set number of versions
	    Report->Error(__("Count of file versions must be a number"));
	    return 0;
	}
    }

    my $channel_string = '';
    my $channel_name = '';
    if ($channel->{'destination'} eq 'file') {
	$channel_name = $SETTINGS->{'logging_channel_file'};
	$channel_string = $channel_name.' { '.
	    'file '.$class->QuoteString($channel->{'filename'}).
	    ($channel->{'versions'} ? ' versions '.$channel->{'versions'} : '').
	    ($channel->{'size'}     ? ' size '.$channel->{'size'}         : '').
	'; }';
    } else {
	$channel_name = $SETTINGS->{'logging_channel_syslog'};
	$channel_string = $channel_name.' { syslog; }';
    }


    my @new_logging = {
	'key'   => 'channel',
	'value' => $channel_string
    };

    # changing logging channel for every used cathegory
    my $categories = $class->GetLoggingCategories();
    foreach (@{$categories}) {
	push @new_logging, {
	    'key' => 'category',
	    'value' => $_.' { '.$channel_name.'; }'
	};
    }

    DnsServer->SetLoggingOptions(\@new_logging);
    return 1;
}

BEGIN{$TYPEINFO{GetLoggingCategories} = ["function", ["list", "string"]]};
sub GetLoggingCategories {
    my $class = shift;

    my @used_categories;
    my $logging = DnsServer->GetLoggingOptions();

    foreach (@{$logging}) {
	if ($_->{'key'} eq 'category') {
	    $_->{'value'} =~ /^[\t ]*([^\t ]+)[\t ]/;
	    if ($1) {
		push @used_categories, $1;
	    } else {
		y2warning("Unknown category format '".$_->{'value'}."'");
	    }
	}
    }

    return \@used_categories;
}

BEGIN{$TYPEINFO{SetLoggingCategories} = ["function", "boolean", ["list", "string"]]};
sub SetLoggingCategories {
    my $class = shift;
    my $categories = shift;

    my $logging_channel = '';
    # we need the destination to be set for each category
    my $channel = $class->GetLoggingChannel();
    if ($channel->{'file'}) {
	$logging_channel = $SETTINGS->{'logging_channel_file'};
    } else {
	$logging_channel = $SETTINGS->{'logging_channel_syslog'};
    }

    my @new_logging;
    
    # defining the chanel
    my $logging = DnsServer->GetLoggingOptions();
    foreach (@{$logging}) {
	if ($_->{'key'} eq 'channel') {
	    push @new_logging, $_;
	    last;
	}
    }
    # defining categories
    foreach (@{$categories}) {
	push @new_logging, {
	    'key'   => 'category',
	    'value' => $_.' { '.$logging_channel.'; }',
	};
    }

    DnsServer->SetLoggingOptions(\@new_logging);
    return 1;
}

BEGIN{$TYPEINFO{GetNamedOptions} = ["function", ["list", ["map", "string", "string"]]]};
sub GetNamedOptions {
    my $class = shift;
    
    return DnsServer->GetGlobalOptions();;
}

BEGIN{$TYPEINFO{GetKnownNamedOptions} = ["function", ["map", "string", ["map", "string", "string"]]]};
sub GetKnownNamedOptions {
    return $OPTIONS;
}

BEGIN{$TYPEINFO{AddNamedOption} = ["function", "boolean", "string", "string", "boolean"]};
sub AddNamedOption {
    my $class = shift;

    my $option = shift;
    my $value  = shift;
    my $force  = shift; # 1 = do not check the syntax

    # FIXME: add an option, SLES

    y2error("NOT IMPLEMENTED YET - SLES FUNCTIONALITY");
}

BEGIN{$TYPEINFO{RemoveNamedOption} = ["function", "boolean", "string", "string"]};
sub RemoveNamedOption {
    my $class = shift;

    my $option = shift;
    my $value  = shift;

    # FIXME: remove an option, SLES

    y2error("NOT IMPLEMENTED YET - SLES FUNCTIONALITY");
}

BEGIN{$TYPEINFO{RemoveNamedOption} = ["function", ["map", "string", ["map", "string", "string"]]]};
sub GetACLs {
    my $class = shift;

    my $return_acls = {
	'any'       => { 'default' => 'yes' },
	'none'      => { 'default' => 'yes' },
	'localnets' => { 'default' => 'yes' },
	'localips'  => { 'default' => 'yes' },
    };

    my $acls = DnsServer->GetAcl();
    foreach my $acl (@{$acls}) {
	#local_ips { 10.20.15.0/20; }
	#friends { 147.8.12.153; 85.15.98.16; 235.8.146.1; }
	$acl =~ /^([^\t ]+)[\t ]*\{([^\}]*)\}/;
	my $name  = $1;
	my $value = $2;
	$value =~ s/(^[\t ]*|[\t ]*$)//g;

	if ($name) {
	    $return_acls->{$name} = { 'value' => $value };
	} else {
	    y2warning("Unknown ACL format '".$acl."'");
	}
    }

    return $return_acls;
}

BEGIN{$TYPEINFO{GetZones} = ["function", ["map", "string", ["map", "string", "string"]]]};
sub GetZones {
    my $class = shift;

    my $zones_return = {};
    my $zones = DnsServer->FetchZones();
    foreach (@$zones) {
	# skipping default (local) zones
	next if ($_->{'zone'} =~ /^(0\.0\.127\.in-addr\.arpa|\.|localhost)$/);
	$zones_return->{$_->{'zone'}}->{'type'} = $_->{'type'};
    }

    return $zones_return;
}

BEGIN{$TYPEINFO{GetZoneMasterServers} = ["function", ["list", "string"], "string"]};
sub GetZoneMasterServers {
    my $class = shift;
    my $zone  = shift;

    return 0 if (!$class->CheckZone($zone));

    my @masters;
    my $zones = DnsServer->FetchZones();
    foreach (@$zones) {
	if ($zone eq $_->{'zone'}) {
	    if ($_->{'type'} eq 'slave') {
		@masters = GetListFromRecord($_->{'masters'});
		last;
	    } else {
		# TRANSLATORS: Popup error message, Trying to get 'master server' for zone which is not 'slave' type, %1 is name of the zone, %2 is type of the zone
		Report->Error(sformat(__("Only 'slave' zones have their 'master server' defined.
Zone '%1' is type '%2'."),$_->{'type'}));
	    }
	}
    }

    return \@masters;
}

BEGIN{$TYPEINFO{SetZoneMasterServers} = ["function", "boolean", "string", ["list", "string"]]};
sub SetZoneMasterServers {
    my $class   = shift;
    my $zone    = shift;
    my $masters = shift;

    return 0 if (!$class->CheckZone($zone));

    my $zones = DnsServer->FetchZones();
    my $zone_counter = 0;
    foreach (@{$zones}) {
	if ($zone eq $_->{'zone'}) {
	    if ($_->{'type'} eq 'slave') {
		$_->{'masters'} = GetRecordFromList(@{$masters});
		@{$zones}[$zone_counter] = $_;
		last;
	    } else {
		# TRANSLATORS: Popup error message, Trying to set 'master server' for zone which is not 'slave' type, %1 is name of the zone, %2 is type of the zone
		Report->Error(sformat(__("Only 'slave' zones have their 'master server' defined.
Zone '%1' is type '%2'."),$_->{'type'}));
	    }
	}
	++$zone_counter;
    }

    return 1;
}

BEGIN{$TYPEINFO{AddZone} = ["function", "boolean", "string", "string", ["map", "string", "string"]]};
sub AddZone {
    my $class   = shift;

    my $zone    = shift;
    my $type    = shift;
    my $options = shift;


    # zone name must be defined
    if (!$zone) {
	# TRANSLATORS: Popup error message, Calling function which needs DNS zone defined
	Report->Error(__("Zone name must be defined."));
	return 0;
    }

    # zone mustn't exist already
    my $zones = $class->GetZones();
    foreach my $known_zone (keys %{$zones}) {
	if ($zone eq $known_zone) {
	    # TRANSLATORS: Popup error message, Trying to add new zone which already exists
	    Report->Error(sformat(__("Zone name '%1' already exists."), $zone));
	    return 0;
	}
    }

    return 0 if (!$class->CheckZoneType($type));

    if ($type eq 'slave' && !$options->{'masterserver'}) {
	# TRANSLATORS: Popup error message, Adding new 'slave' zone without defined needed option 'masterserver'
	Report->Error(__("Option 'masterserver' is needed for 'slave' zones."));
	return 0;
    }

    DnsServer->SelectZone(-1);
    my $new_zone = DnsServer->FetchCurrentZone();
    $new_zone->{'zone'} = $zone;
    $new_zone->{'type'} = $type;
    DnsServer->StoreCurrentZone($new_zone);
    DnsServer->StoreZone();

    if ($type eq 'slave') {
	my @masters = $options->{'masterserver'};
	$class->SetZoneMasterServers($zone,\@masters);
    }

    return 1;
}

BEGIN{$TYPEINFO{RemoveZone} = ["function", "boolean", "string"]};
sub RemoveZone {
    my $class = shift;
    my $zone = shift;

    return 0 if (!$class->CheckZone($zone));

    my $zones = DnsServer->FetchZones();
    my @new_zones;
    foreach (@{$zones}) {
	# skipping zone to be deleted
	next if ($_->{'zone'} eq $zone);
	push @new_zones, $_;
    }
    DnsServer->StoreZones(\@new_zones);

    return 1;
}

BEGIN{$TYPEINFO{GetZoneTransportACLs} = ["function", ["list", "string"], "string"]};
sub GetZoneTransportACLs {
    my $class = shift;
    my $zone  = shift;

    return 0 if (!$class->CheckZone($zone));
    
    my @used_acls;
    my $zones = DnsServer->FetchZones();
    foreach (@{$zones}) {
	if ($_->{'zone'} eq $zone) {
	    foreach (@{$_->{'options'}}) {
		if ($_->{'key'} eq 'allow-transfer') {
		    @used_acls = GetListFromRecord($_->{'value'});
		    last;
		}
	    }
	    last;
	}
    }

    return \@used_acls;
}

sub SetZoneTransportACLs {
    my $class = shift;
    my $zone  = shift;
    my $acls  = shift;

    return 0 if (!$class->CheckZone($zone));

    my $zones = DnsServer->FetchZones();
    my $zone_counter = 0;
    foreach (@{$zones}) {
	if ($_->{'zone'} eq $zone) {
	    my @new_options;
	    foreach (@{$_->{'options'}}) {
		# removing all allow-transfer from options, getting allow-transfer
		if ($_->{'key'} eq 'allow-transfer') {
		    next;
		} else {
		# adding all non-allow-transfer from options
		    push @new_options, $_;
		}
	    }
	    push @new_options, { 'key' => 'allow-transfer', 'value' => GetRecordFromList(@{$acls}) };
	    $_->{'options'} = \@new_options;
	    @{$zones}[$zone_counter] = $_;
	    last;
	}
	++$zone_counter;
    }
    DnsServer->StoreZones($zones);

    return 1;
}

BEGIN{$TYPEINFO{AddZoneTransportACL} = ["function", "boolean", "string", "string"]};
sub AddZoneTransportACL {
    my $class = shift;
    my $zone  = shift;
    my $acl   = shift;

    return 0 if (!$class->CheckZone($zone));
    return 0 if (!$class->CheckTransportACL($acl));

    my @used_acls = ToSet(@{$class->GetZoneTransportACLs($zone)}, $acl);
    $class->SetZoneTransportACLs($zone, \@used_acls);
}

BEGIN{$TYPEINFO{RemoveZoneTransportACL} = ["function", "boolean", "string", "string"]};
sub RemoveZoneTransportACL {
    my $class = shift;
    my $zone  = shift;
    my $acl   = shift;

    return if (!$class->CheckZone($zone));
    return 0 if (!$class->CheckTransportACL($acl));

    my @used_acls = ToSet(@{$class->GetZoneTransportACLs($zone)}, $acl);
    @used_acls = grep { !/^$acl$/ } @used_acls;
    $class->SetZoneTransportACLs($zone, \@used_acls);
}

sub GetZoneRecords {
    my $class = shift;
    my $zone  = shift;
    my $types = shift; # none means all types

    return 0 if (!$class->CheckZone($zone));

    # FIXME: param checking

    my $check_types = 0;
    $check_types = 1 if (scalar(@{$types})>0);

    my @records;
    my $zones = DnsServer->FetchZones();
    foreach (@{$zones}) {
	if ($_->{'zone'} eq $zone) {
	    foreach (@{$_->{'records'}}) {
		if ($check_types) {
		    # skipping record if type doesn't match
		    my $type = $_->{'type'};
		    next if (grep { !/^$type$/ } @{$types});
		}
		push @records, $_;
	    }
	    last;
	}
    }

    return \@records;
}

BEGIN{$TYPEINFO{GetZoneNameServers} = ["function", ["list", "string"], "string"]};
sub GetZoneNameServers {
    my $class = shift;
    my $zone  = shift;

    return 0 if (!$class->CheckZone($zone));

    my @types = ('NS');
    my @nameservers;
    foreach (@{$class->GetZoneRecords($zone, \@types)}) {
	# xyz.com. (ending with a dot) - getting NS servers only for the whole domain
	push @nameservers, $_->{'value'} if ($_->{'key'} eq $zone.'.');
    }

    return \@nameservers;
}

BEGIN{$TYPEINFO{GetZoneMailServers} = ["function", ["list", ["map", "string", "string"]], "string"]};
sub GetZoneMailServers {
    my $class = shift;
    my $zone  = shift;

    return 0 if (!$class->CheckZone($zone));

    my @types = ('MX');
    my @mailservers;
    foreach (@{$class->GetZoneRecords($zone, \@types)}) {
	# xyz.com. (ending with a dot) - getting MX servers only for the whole domain
	if ($_->{'key'} eq $zone.'.') {
	    if ($_->{'value'} =~ /[\t ]*(\d+)[\t ]+([^\t ]+)$/) {
		push @mailservers, { $2 => $1 };
	    } else {
		# FIXME: unknown MX server type !'prio hostname'
	    }
	}
    }

    return \@mailservers;
}

BEGIN{$TYPEINFO{GetZoneRRs} = ["function", ["list", ["map", "string", "string"]], "string"]};
sub GetZoneRRs {
    my $class = shift;
    my $zone  = shift;

    return 0 if (!$class->CheckZone($zone));

    my @records;
    my @types;
    foreach (@{$class->GetZoneRecords($zone,\@types)}) {
	# filtering zone NS
	next if ($_->{'type'} eq 'NS' && $_->{'key'} eq $zone.'.');
	# filtering zone MX
	next if ($_->{'type'} eq 'MX' && $_->{'key'} eq $zone.'.');
	push @records, $_;
    }

    return \@records;
}

BEGIN{$TYPEINFO{AddZoneRR} = ["function","boolean","string","string","string","string"]};
sub AddZoneRR {
    my $class = shift;

    my $zone  = shift;
    my $type  = uc(shift) || '';
    my $key   = shift || '';
    my $value = shift || '';

    return 0 if (!$class->CheckZone($zone));

    if (!$type) {
	# TRANSLATORS: Popup error message, Trying to add record without defined type
	Report->Error("DNS resource record type must be defined.");
	return 0;
    }
    if (!$key) {
	# TRANSLATORS: Popup error message, Trying to add record without key
	Report->Error("DNS resource record key must be defined.");
	return 0;
    }
    if (!$value) {
	# TRANSLATORS: Popup error message, Trying to add record without value
	Report->Error("DNS resource record value must be defined.");
	return 0;
    }

    # replacing all spaces with one space char (MX servers are affected)
    $value =~ s/[\t ]+/ /g;

    return 0 if (!$class->CheckResourceRecord({ 'type' => $type, 'key' => $key, 'value' => $value }));

    my $zones = DnsServer->FetchZones();
    my @new_records;
    my $new_zone = {};
    my $zone_index = 0;
    foreach (@{$zones}) {
	if ($_->{'zone'} eq $zone) {
	    foreach (@{$_->{'records'}}) {
		# replacing all spaces with one space char (MX servers are affected)
		$_->{'value'} =~ s/[\t ]+/ /g;
		if ($_->{'type'} eq $type && $_->{'key'} eq $key && $_->{'value'} eq $value) {
		    # the same record exists already
		    return 1;
		}
	    }
	    @new_records = @{$_->{'records'}};
	    push @new_records, { 'type' => $type, 'key' => $key, 'value' => $value };
	    $new_zone = @{$zones}[$zone_index];
	    $new_zone->{'records'} = \@new_records;
	    last;
	}
	++$zone_index;
    }
    @{$zones}[$zone_index] = $new_zone;
    DnsServer->StoreZones($zones);

    return 1;
}

BEGIN{$TYPEINFO{RemoveZoneRR} = ["function","boolean","string","string","string","string"]};
sub RemoveZoneRR {
    my $class = shift;

    my $zone  = shift;
    my $type  = shift;
    my $key   = shift;
    my $value = shift;

    return 0 if (!$class->CheckZone($zone));

    if (!$type) {
	# TRANSLATORS: Popup error message, Trying to remove record without defined type
	Report->Error("DNS resource record type must be defined.");
	return 0;
    }
    if (!$key) {
	# TRANSLATORS: Popup error message, Trying to remove record without key
	Report->Error("DNS resource record key must be defined.");
	return 0;
    }
    if (!$value) {
	# TRANSLATORS: Popup error message, Trying to remove record without value
	Report->Error("DNS resource record value must be defined.");
	return 0;
    }

    my $zones = DnsServer->FetchZones();
    my @new_records;
    my $new_zone = {};
    my $zone_index = 0;
    foreach (@{$zones}) {
	if ($_->{'zone'} eq $zone) {
	    my $record_found = 0;
	    foreach (@{$_->{'records'}}) {
		# replacing all spaces with one space char (MX servers are affected)
		$_->{'value'} =~ s/[\t ]+/ /g;
		if ($_->{'type'} eq $type && $_->{'key'} eq $key && $_->{'value'} eq $value) {
		    # gottcha!
		    $record_found = 1;
		} else {
		    push @new_records, $_;
		}
	    }
	    if (!$record_found) {
		# such record doesn't exist
		return 1;
	    }
	    $new_zone = @{$zones}[$zone_index];
	    $new_zone->{'records'} = \@new_records;
	    last;
	}
	++$zone_index;
    }
    @{$zones}[$zone_index] = $new_zone;
    DnsServer->StoreZones($zones);

    return 1;
}

BEGIN{$TYPEINFO{AddZoneNameServer} = ["function","boolean","string","string"]};
sub AddZoneNameServer {
    my $class = shift;

    my $zone   = shift;
    my $server = shift || '';

    # zone checking is done in AddZoneRR() function

    return $class->AddZoneRR($zone, 'NS', $zone.'.', $server);
}

BEGIN{$TYPEINFO{RemoveZoneNameServer} = ["function","boolean","string","string"]};
sub RemoveZoneNameServer {
    my $class = shift;

    my $zone   = shift;
    my $server = shift || '';

    # zone checking is done in RemoveZoneRR() function

    return $class->RemoveZoneRR($zone, 'NS', $zone.'.', $server);
}

BEGIN{$TYPEINFO{AddZoneMailServer} = ["function","boolean","string","string","integer"]};
sub AddZoneMailServer {
    my $class = shift;

    my $zone   = shift;
    my $server = shift || '';
    my $prio   = shift || '';

    # zone checking is done in AddZoneRR() function

    return $class->AddZoneRR($zone, 'MX', $zone.'.', $prio.' '.$server);
}

BEGIN{$TYPEINFO{RemoveZoneMailServer} = ["function","boolean","string","string","integer"]};
sub RemoveZoneMailServer {
    my $class = shift;

    my $zone   = shift;
    my $server = shift || '';
    my $prio   = shift || '';

    # zone checking is done in RemoveZoneRR() function

    return $class->RemoveZoneRR($zone, 'MX', $zone.'.', $prio.' '.$server);
}

BEGIN{$TYPEINFO{GetZoneSOA} = ["function",["map","string","string"],"string"]};
sub GetZoneSOA {
    my $class = shift;
    my $zone  = shift;

    return 0 if (!$class->CheckZone($zone));

    my $return = {};

    my $zones = DnsServer->FetchZones();
    foreach (@{$zones}) {
	if ($_->{'zone'} eq $zone) {
	    foreach my $key ('minimum', 'expiry', 'serial', 'retry', 'refresh', 'mail', 'server') {
		$return->{$key} = $_->{'soa'}->{$key};
	    }
	    last;
	}
    }

    return $return;
}

BEGIN{$TYPEINFO{SetZoneSOA} = ["function","boolean","string",["map","string","string"]]};
sub SetZoneSOA {
    my $class = shift;
    my $zone  = shift;
    my $SOA   = shift;

    return 0 if (!$class->CheckZone($zone));

    my $zones = DnsServer->FetchZones();
    my $zone_index = 0;
    my $new_zone = {};
    foreach (@{$zones}) {
	if ($_->{'zone'} eq $zone) {
	    my $new_SOA = $_->{'soa'};
	    foreach my $key ('minimum', 'expiry', 'serial', 'retry', 'refresh', 'mail', 'server') {
		# changing current SOA with new values
		if (defined $SOA->{$key}) {
		    $new_SOA->{$key} = $SOA->{$key};
		}
	    }
	    $new_zone = $_;
	    $new_zone->{'soa'} = $new_SOA;
	    last;
	}
	++$zone_index;
    }
    @{$zones}[$zone_index] = $new_zone;
    DnsServer->StoreZones($zones);
}

1;
