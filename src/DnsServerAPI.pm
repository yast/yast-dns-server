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

use YaST::YCP qw( sformat y2milestone y2error y2warning );
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
    my $record = shift || '';
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
	# TRANSLATORS: Popup error message during parameters validation,
	#   %1 is a string which is needed to be an IPv4
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
    
    # TRANSLATORS: Popup error message, Trying to get information from zone which doesn't exist,
    #   %1 is the zone name
    Report->Error(sformat(__("DNS zone '%1' does not exist."), $zone));
    return 0;
}

sub ZoneIsMaster {
    my $class = shift;
    my $zone  = shift || '';

    if (!$zone) {
	y2error("Zone must be defined");
	return 0;
    }

    my $zones = $class->GetZones();
    foreach my $known_zone (keys %{$zones}) {
	return 1 if ($zone eq $known_zone && $zones->{$known_zone}->{'type'} eq 'master');
    }

    # TRANSLATORS: Popup error message, Trying manage records in zone which is not 'master' type
    #   only 'master' zone records can be managed
    #   %1 is the zone name
    Report->Error(sformat(__("DNS zone '%1' is not type 'master'."), $zone));
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
	# TRANSLATORS: Popup error message, Calling function with unsupported DNZ zone type,
	#   %1 is the zone type
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

    # TRANSLATORS:  Popup error message, Calling function with unknown ACL,
    #   %1 is the ACL's name
    Report->Error(sformat(__("ACL named '%1' does not exist."), $acl));
    return 0;
}

sub CheckHostname {
    my $class = shift;
    my $hostname = shift || '';

    if (!$hostname) {
	# TRANSLATORS:  Popup error message, Calling function with undefined parameter
	Report->Error(__("Host name must be defined."));
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
		Report->Error(__("Wrong format of fully qualified host name."));
		return 0;
	    }
	# DNS FQDN which doesn't finish with a dot!
	} else {
	    # Popup error message, FQDN hostname must finish with a dot
	    Report->Error(__("Fully qualified host name must be finished with a dot."));
	    return 0;
	}
    # Relative name
    } else {
	if (Hostname->Check($hostname)) {
	    return 1;
	} else {
	    # TRANSLATORS: Popup error message, wrong hostname, allowed syntax is described
	    #   two lines below using a pre-defined text
	    Report->Error(__("Wrong format of host name.")."\n\n".Hostname->ValidHost());
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

    return 1;
}

sub CheckHostameInZone {
    my $class    = shift;
    my $hostname = shift || '';
    my $zone     = shift || '';

    # hostname is not relative
    if ($hostname =~ /\.$/) {
	# hostname does not end with the zone name (A, NS, MX ...)
	# hostname is not the same as the zone (domain NS, domain MX...)
	if ($hostname !~ /\.$zone\.$/ && $hostname !~ /^$zone\.$/) {
	    # TRANSLATORS: Popup error message, Wrong hostname which should be part of the zone,
	    #   %1 is the hostname, %2 is the zone name
	    Report->Error(sformat(__("Host name '%1' is not part of the zone '%2'.

Host name must be relative to the zone or must end with the zone name
followed by a dot.
Such as 'dhcp1' or 'dhcp1.example.org.' for the zone 'dhcp.org'."), $hostname, $zone));
	    return 0;
	}
    }

    return 1;
}

sub CheckReverseIPv4 {
    my $class  = shift;
    my $reverseip = lc(shift) || '';

    # 1 integer
    if ($reverseip =~ /^(\d+)$/) {
	return 1 if ($1>=0 && $1<256);
    # 2 integers
    } elsif ($reverseip =~ /^(\d+)\.(\d+).(\d+)$/) {
	return 1 if ($1>=0 && $1<256 && $2>=0 && $2<256);
    # 3 integers
    } elsif ($reverseip =~ /^(\d+)\.(\d+).(\d+)$/) {
	return 1 if ($1>=0 && $1<256 && $2>=0 && $2<256 && $3>=0 && $3<256);
    # 4 integers
    } elsif ($reverseip =~ /^(\d+)\.(\d+).(\d+).(\d+)$/) {
	return 1 if ($1>=0 && $1<256 && $2>=0 && $2<256 && $3>=0 && $3<256 && $4>=0 && $4<256);
    # full format
    } elsif ($reverseip =~ /^(\d+)\.(\d+).(\d+).(\d+)\.in-addr\.arpa\.$/) {
	return 1 if ($1>=0 && $1<256 && $2>=0 && $2<256 && $3>=0 && $3<256 && $4>=0 && $4<256);
    }

    # TRANSLATORS: Popup error message, Wrong reverse IPv4,
    #   %1 is the reveresed IPv4
    Report->Error(sformat(__("Wrong format of reverse IPv4 address '%1'.

Valid reverse IPv4 consists of four integers in range 0-255
separated by a dot followed by string '.in-addr.arpa.'.

Such as '1.32.168.192.in-addr.arpa.' for '192.168.32.1' IPv4 address."), $reverseip));
    return 0;
}

sub CheckHostnameRelativity {
    my $class    = shift;
    my $hostname = shift || '';
    my $zone     = shift || '';

    # ending with a dot - it isn't relative
    if ($hostname =~ /\.$/) {
	return 1;
    }

    if ($zone =~ /\.in-addr\.arpa$/) {
	# TRANSLATORS: Popup error message, user can't use hostname %1 because it doesn't make
	#   sense to e relative to zone %2 (%2 is a reverse zone name like '32.200.192.in-addr.arpa')
	Report->Error(sformat(__("Relative host name '%1' cannot be used with zone '%2'.
Use fully qualified host name finished with a dot instead.
Such as 'host.example.org.'"), $hostname, $zone));
	return 0;
    }

    return 1;
}

sub GetFullHostname {
    my $class    = shift;
    my $zone     = shift || '';
    my $hostname = shift || '';

    # record is realtive and is not IPv4
    if ($hostname !~ /\.$/ && !IP->Check4($hostname)) {
	$hostname .= '.'.$zone.'.';
    }

    return $hostname;
}

sub CheckResourceRecord {
    my $class  = shift;
    my $record = shift || {};

    foreach my $key ('type', 'key', 'value', 'zone') {
	$record->{$key} = '' if (not defined $record->{$key});
    }
    $record->{'type'} = uc($record->{'type'});

    if (!$record->{'type'}) {
	return 0;
    }

    if ($record->{'type'} eq 'A') {
	return 0 if (!$class->CheckHostname($record->{'key'}));
	return 0 if (!$class->CheckHostameInZone($record->{'key'},$record->{'zone'}));
	return 0 if (!$class->CheckIPv4($record->{'value'}));
	return 1;
    } elsif ($record->{'type'} eq 'CNAME') {
	return 0 if (!$class->CheckHostname($record->{'key'}));
	return 0 if (!$class->CheckHostameInZone($record->{'key'},$record->{'zone'}));
	return 0 if (!$class->CheckHostname($record->{'value'}));
	return 1;
    } elsif ($record->{'type'} eq 'PTR') {
	return 0 if (!$class->CheckReverseIPv4($record->{'key'}));
	return 0 if (!$class->CheckHostameInZone($record->{'key'},$record->{'zone'}));
	return 0 if (!$class->CheckHostname($record->{'value'}));
	return 1;
    } elsif ($record->{'type'} eq 'NS') {
	return 0 if (!$class->CheckHostname($record->{'key'}));
	return 0 if (!$class->CheckHostameInZone($record->{'key'},$record->{'zone'}));
	return 0 if (!$class->CheckHostnameRelativity($record->{'value'},$record->{'zone'}));
	return 0 if (!$class->CheckHostname($record->{'value'}));
	return 1;
    } elsif ($record->{'type'} eq 'MX') {
	return 0 if (!$class->CheckHostname($record->{'key'}));
	return 0 if (!$class->CheckHostameInZone($record->{'key'},$record->{'zone'}));
	return 0 if (!$class->CheckHostnameRelativity($record->{'value'},$record->{'zone'}));
	# format: 'priority server.name'
	if ($record->{'value'} =~ /^[\t ]*([^\t ]+)[\t ]+(.*)$/) {
	    return 0 if (!$class->CheckHostname($2));
	    return 0 if (!$class->CheckMXPriority($1));
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

BEGIN{$TYPEINFO{TimeToSeconds} = ["function", "integer", "string"]};
sub TimeToSeconds {
    my $class        = shift;
    my $originaltime = shift || '';

    my $time      = $originaltime;
    my $totaltime = 0;
    while ($time =~ s/^(\d+)([WDHMS])//i) {
	if ($2 eq 'W' || $2 eq 'w') {
	    $totaltime += $1 * 604800;
	} elsif ($2 eq 'D' || $2 eq 'd') {
	    $totaltime += $1 * 86400;
	} elsif ($2 eq 'H' || $2 eq 'h') {
	    $totaltime += $1 * 3600;
	} elsif ($2 eq 'M' || $2 eq 'm') {
	    $totaltime += $1 * 60;
	} elsif ($2 eq 'S' || $2 eq 's') {
	    $totaltime += $1;
	}
    }
    if ($time =~ s/^\d+$//) {
	$totaltime += $time;
    }
    if ($time ne '') {
	y2error("Wrong time format '".$originaltime."', unable to parse.");
	return undef;
    }

    return $totaltime;
}

BEGIN{$TYPEINFO{SecondsToHighestTimeUnit} = ["function", "string", "integer"]};
sub SecondsToHighestTimeUnit {
    my $class   = shift;
    my $seconds = shift || 0;

    if ($seconds <= 0) {
	return $seconds;
    }

    my $units = {
	'W' => 604800,
	'D' => 86400,
	'H' => 3600,
	'M' => 60,
	'S' => 1,
    };

    foreach my $unit ('W', 'D', 'H', 'M', 'S') {
	if ($seconds % $units->{$unit} == 0) {
	    return (($seconds / $units->{$unit}).$unit);
	}
    }
}

sub CheckBINDTimeValue {
    my $class = shift;
    my $key   = shift || '';
    my $time  = shift || '';

    # translate bind time to seconds
    $time = $class->TimeToSeconds($time) || do {
	# undef returned
	return 0 if ($time eq undef);
    };

    if ($key eq 'ttl') {
	# RFC 2181
	if ($time < 0 || $time > 2147483647) {
	    # TRANSLATORS: Popup error message, Checking time value for specific SOA section (key),
	    #   %1 is the section name, %2 is the minimal value, %3 si the maximal value of the section
	    Report->Error(sformat(__("Wrong SOA record.
Section '%1' must be in range from %2 to %3 seconds."), $key, 0, 2147483647));
	    return 0;
	}
	return 1;
    } elsif ($key eq 'minimum') {
	# RFC 2308, BIND 9 specific
	if ($time < 0 || $time > 10800) {
	    # TRANSLATORS: Popup error message, Checking time value for specific SOA section (key),
	    #   %1 is the section name, %2 is the minimal value, %3 si the maximal value of the section
	    Report->Error(sformat(__("Wrong SOA record.
Section '%1' must be in range from %2 to %3 seconds."), $key, 0, 10800));
	    return 0;
	}	
    }

    return 1;
}

sub CheckBINDTimeFormat {
    my $class = shift;
    my $key   = shift || '';
    my $time  = shift || '';

    # must be defined (non-empty string)
    if ($time ne '' && (
	# number with suffix and combinations, case insensitive
	$time =~ /^(\d+W)?(\d+D)?(\d+H)?(\d+M)?(\d+S)?$/i
	||
	# only number
	$time =~ /^\d+$/
    )) {
	return 1;
    }

    # TRANSLATORS: Popup error message, Checking special BIND time format consisting of numbers
    #   and defined suffies, also only number (as seconds) is allowed, %1 is a section name
    #   like 'ttl' or 'refresh'
    Report->Error(sformat(__("Wrong SOA record.
    Section '%1' must be a BIND time type.
BIND time type consists of numbers and case insensitive
suffixes W, D, H, M and S. Time in seconds is allowed without suffix.
Such as 12H15m, 86400 or 1W30M."), $key));
    return 0;
}

sub CheckBINDTime {
    my $class = shift;
    my $key   = shift || '';
    my $time  = shift || '';

    return 0 if (!$class->CheckBINDTimeFormat($key,$time));
    return 0 if (!$class->CheckBINDTimeValue ($key,$time));
    return 1;
}

sub CheckSOARecord {
    my $class = shift;
    my $key   = shift || '';
    my $value = shift || '';

    # only number
    if ($key eq 'serial') {
	# 32 bit unsigned integer
	my $max_serial = 4294967295;
	if ($value !~ /^\d+$/ || $value > $max_serial) {
	    # TRANSLATORS: Popup error message, Checking SOA record,
	    #   %1 is a part of SOA, %2 is typically 0, %3 is some huge number
	    Report->Error(sformat(__("Wrong SOA record.
Section '%1' must be a number between %2 and %3 included."), 'serial', 0, $max_serial));
	    return 0;
	}
	return 1;
    # BIND time type
    } else {
	return 0 if (!$class->CheckBINDTime($key,$value));
	return 1;
    }
}

# Function returns quoted string by a double-quote >>"<<
# 'A"b"Cd42' -> '"A\"b\"Cd42"'
sub QuoteString {
    my $class = shift;
    
    my $string = shift || '';
    my $quote  = '"';

    $string =~ s/\\/\\\\/g;
    $string =~ s/$quote/\\$quote/g;
    $string = $quote.$string.$quote;

    return $string;
}

sub UnquoteString {
    my $class = shift;
    
    my $string = shift || '';
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

BEGIN{$TYPEINFO{Write} = ["function", "boolean"]};
sub Write {
    my $class = shift;
    
    my $progress_orig = Progress->set (0);
    my $ret = DnsServer->Write ();
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
    my $new_one = shift || '';

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
    my $remove_this = shift || '';

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
    my $channel = shift || {};

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
    if ($channel->{'destination'} eq 'file') {
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

BEGIN{$TYPEINFO{GetACLs} = ["function", ["map", "string", ["map", "string", "string"]]]};
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
    my $zone  = shift || '';

    return 0 if (!$class->CheckZone($zone));

    my @masters;
    my $zones = DnsServer->FetchZones();
    foreach (@$zones) {
	if ($zone eq $_->{'zone'}) {
	    if ($_->{'type'} eq 'slave') {
		@masters = GetListFromRecord($_->{'masters'});
		last;
	    } else {
		# TRANSLATORS: Popup error message, Trying to get 'master server' for zone which is not 'slave' type,
		#   'master' servers haven't any 'masterservers', they ARE masterservers
		#   %1 is name of the zone, %2 is type of the zone
		Report->Error(sformat(__("Only 'slave' zones have their 'master server' defined.
Zone '%1' is type '%2'."), $_->{'zone'}, $_->{'type'}));
	    }
	}
    }

    return \@masters;
}

BEGIN{$TYPEINFO{SetZoneMasterServers} = ["function", "boolean", "string", ["list", "string"]]};
sub SetZoneMasterServers {
    my $class   = shift;
    my $zone    = shift || '';
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
		# TRANSLATORS: Popup error message, Trying to set 'master server' for zone which is not 'slave' type,
		#   %1 is name of the zone, %2 is type of the zone
		Report->Error(sformat(__("Only 'slave' zones have their 'master server' defined.
Zone '%1' is type '%2'."), $_->{'zone'}, $_->{'type'}));
	    }
	}
	++$zone_counter;
    }

    return 1;
}

BEGIN{$TYPEINFO{AddZone} = ["function", "boolean", "string", "string", ["map", "string", "string"]]};
sub AddZone {
    my $class   = shift;

    my $zone    = shift || '';
    my $type    = shift || '';
    my $options = shift || {};


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
    my $zone = shift || '';

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
    my $zone  = shift || '';

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

# hidden function
sub SetZoneTransportACLs {
    my $class = shift;
    my $zone  = shift || '';
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
    my $zone  = shift || '';
    my $acl   = shift || '';

    return 0 if (!$class->CheckZone($zone));
    return 0 if (!$class->CheckTransportACL($acl));

    my @used_acls = ToSet(@{$class->GetZoneTransportACLs($zone)}, $acl);
    $class->SetZoneTransportACLs($zone, \@used_acls);
}

BEGIN{$TYPEINFO{RemoveZoneTransportACL} = ["function", "boolean", "string", "string"]};
sub RemoveZoneTransportACL {
    my $class = shift;
    my $zone  = shift || '';
    my $acl   = shift || '';

    return if (!$class->CheckZone($zone));
    return 0 if (!$class->CheckTransportACL($acl));

    my @used_acls = ToSet(@{$class->GetZoneTransportACLs($zone)}, $acl);
    @used_acls = grep { !/^$acl$/ } @used_acls;
    $class->SetZoneTransportACLs($zone, \@used_acls);
}

sub GetZoneRecords {
    my $class = shift;
    my $zone  = shift || '';
    my $types = shift; # none means all types

    return 0 if (!$class->CheckZone($zone));

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
		    next if (!DnsServer->contains($types, $type));
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
    my $zone  = shift || '';

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
    my $zone  = shift || '';

    return 0 if (!$class->CheckZone($zone));

    my @types = ('MX');
    my @mailservers;
    foreach (@{$class->GetZoneRecords($zone, \@types)}) {
	# xyz.com. (ending with a dot) - getting MX servers only for the whole domain
	if ($_->{'key'} eq $zone.'.') {
	    if ($_->{'value'} =~ /[\t ]*(\d+)[\t ]+([^\t ]+)$/) {
		push @mailservers, {
		    'name'	=> $2,
		    'priority'	=> $1
		};
	    } else {
		y2error("Unknown MX server '".$_->{'value'}."'");
	    }
	}
    }

    return \@mailservers;
}

BEGIN{$TYPEINFO{GetZoneRRs} = ["function", ["list", ["map", "string", "string"]], "string"]};
sub GetZoneRRs {
    my $class = shift;
    my $zone  = shift || '';

    return 0 if (!$class->CheckZone($zone));

    my @records;
    my @types;
    foreach (@{$class->GetZoneRecords($zone,\@types)}) {
	# filtering zone NS
	next if ($_->{'type'} eq 'NS' && $_->{'key'} eq $zone.'.');
	# filtering zone MX
	next if ($_->{'type'} eq 'MX' && $_->{'key'} eq $zone.'.');
	# filtering zone ORIGIN
	next if ($_->{'type'} eq 'ORIGIN');
	push @records, $_;
    }

    return \@records;
}

BEGIN{$TYPEINFO{AddZoneRR} = ["function","boolean","string","string","string","string"]};
sub AddZoneRR {
    my $class = shift;

    my $zone  = shift || '';
    my $type  = uc(shift) || '';
    my $key   = lc(shift) || '';
    my $value = lc(shift) || '';

    return 0 if (!$class->CheckZone($zone));
    return 0 if (!$class->ZoneIsMaster($zone));

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

    return 0 if (!$class->CheckResourceRecord({
	'type' => $type, 'key' => $key, 'value' => $value, 'zone' => $zone
    }));

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
		    # the same record exists already, just return true
		    return 1;
		}
	    }
	    @new_records = @{$_->{'records'}};
	    push @new_records, { 'type' => $type, 'key' => $key, 'value' => $value };
	    $new_zone = @{$zones}[$zone_index];
	    $new_zone->{'records'} = \@new_records;
	    $new_zone->{'modified'} = 1;
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

    my $zone  = shift || '';

    # lowering all values, types are allways uppercased
    my $type  = uc(shift) || '';
    my $key   = lc(shift) || '';
    my $value = lc(shift) || '';
    my $prio  = ''; # used for MX records

    return 0 if (!$class->CheckZone($zone));
    return 0 if (!$class->ZoneIsMaster($zone));

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

    $value =~ s/(^[\t ]+|[\t ]+$)//g;
    if ($type eq 'MX') {
	$value =~ s/^(\d+)[\t ]+([^\t ]*)$/$2/g;
	if ($1 ne '') {
	    $prio = $1;
	} else {
	    y2error("Unknown MX recod '".$key."/".$type."/".$value."'");
	}
    }

    my $zones = DnsServer->FetchZones();
    my @new_records;
    my $new_zone = {};
    my $zone_index = 0;
    foreach (@{$zones}) {
	if ($_->{'zone'} eq $zone) {
	    my $record_found = 0;
	    foreach (@{$_->{'records'}}) {
		# for backup
		my $this_record = {
		    'key'   => $_->{'key'},
		    'type'  => $_->{'type'},
		    'value' => $_->{'value'},
		};

		$_->{'prio'} = '';

		if ($_->{'type'} eq 'MX') {
		    # replacing all spaces with one space char (MX servers are affected)
		    $_->{'value'} =~ s/(^[\t ]+|[\t ]+$)//g;
		    $_->{'value'} =~ s/^(\d+)[\t ]+([^\t ]*)$/$2/g;
		    if ($1 ne '') {
			$_->{'prio'}  = $1;
		    } else {
			y2error("Unknown MX recod '".$_->{'key'}."/".$_->{'type'}."/".$_->{'value'}."'");
		    }
		}
		
		# lowering all values, types are allways uppercased
		$_->{'type'}  = uc($_->{'type'});
		$_->{'key'}   = lc($_->{'key'});
		$_->{'value'} = lc($_->{'value'});
		
		# matching
		if ($_->{'type'} eq $type) {
		
		    # non-MX record non-realtive
		    if ($_->{'type'} ne 'MX' &&
			    $_->{'key'} eq $key && $_->{'value'} eq $value) {
			# gottcha!
			$record_found = 1;
			next;
		    # MX record non-realtive
		    } elsif ($_->{'type'} eq 'MX' &&
			    $_->{'key'} eq $key && $_->{'prio'}.' '.$_->{'value'} eq $prio.' '.$value) {
			# gottcha!
			$record_found = 1;
			next;
		    # relative record
		    } else {
			# transform all relative names to their absolute form
			$_->{'key'}   = $class->GetFullHostname($zone, $_->{'key'});
			$key          = $class->GetFullHostname($zone, $key);
			$_->{'value'} = $class->GetFullHostname($zone, $_->{'value'});
			$value        = $class->GetFullHostname($zone, $value);
			
			# non-MX record realtive
			if ($_->{'type'} ne 'MX' &&
				$_->{'key'} eq $key && $_->{'value'} eq $value) {
			    # gottcha!
			    $record_found = 1;
			    next;
			# MX record realtive
			} elsif ($_->{'type'} eq 'MX' &&
				$_->{'key'} eq $key && $_->{'prio'}.' '.$_->{'value'} eq $prio.' '.$value) {
			    # gottcha!
			    $record_found = 1;
			    next;
			}
		    }
		}

		push @new_records, $this_record;
	    }
	    if (!$record_found) {
		# such record doesn't exist
		return 1;
	    }
	    $new_zone = @{$zones}[$zone_index];
	    $new_zone->{'records'} = \@new_records;
	    $new_zone->{'modified'} = 1;
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

    my $zone   = shift || '';
    my $server = shift || '';

    # zone checking is done in AddZoneRR() function

    return $class->AddZoneRR($zone, 'NS', $zone.'.', $server);
}

BEGIN{$TYPEINFO{RemoveZoneNameServer} = ["function","boolean","string","string"]};
sub RemoveZoneNameServer {
    my $class = shift;

    my $zone   = shift || '';
    my $server = shift || '';

    # zone checking is done in RemoveZoneRR() function

    return $class->RemoveZoneRR($zone, 'NS', $zone.'.', $server);
}

BEGIN{$TYPEINFO{AddZoneMailServer} = ["function","boolean","string","string","integer"]};
sub AddZoneMailServer {
    my $class = shift;

    my $zone   = shift || '';
    my $server = shift || '';
    my $prio   = shift || '';

    # zone checking is done in AddZoneRR() function

    return $class->AddZoneRR($zone, 'MX', $zone.'.', $prio.' '.$server);
}

BEGIN{$TYPEINFO{RemoveZoneMailServer} = ["function","boolean","string","string","integer"]};
sub RemoveZoneMailServer {
    my $class = shift;

    my $zone   = shift || '';
    my $server = shift || '';
    my $prio   = shift || '';

    # zone checking is done in RemoveZoneRR() function

    return $class->RemoveZoneRR($zone, 'MX', $zone.'.', $prio.' '.$server);
}

BEGIN{$TYPEINFO{GetZoneSOA} = ["function",["map","string","string"],"string"]};
sub GetZoneSOA {
    my $class = shift;
    my $zone  = shift || '';

    return {} if (!$class->CheckZone($zone));
    return {} if (!$class->ZoneIsMaster($zone));

    my $return = {};

    my $zones = DnsServer->FetchZones();
    foreach (@{$zones}) {
	if ($_->{'zone'} eq $zone) {
	    foreach my $key ('minimum', 'expiry', 'serial', 'retry', 'refresh', 'mail', 'server') {
		if (defined $_->{'soa'}->{$key}) {
		    $return->{$key} = $_->{'soa'}->{$key};
		}
	    }
	    if (defined $_->{'ttl'}) {
		$return->{'ttl'} = $_->{'ttl'};
	    }
	    last;
	}
    }

    return $return;
}

BEGIN{$TYPEINFO{SetZoneSOA} = ["function","boolean","string",["map","string","string"]]};
sub SetZoneSOA {
    my $class = shift;
    my $zone  = shift || '';
    my $SOA   = shift || {};

    return 0 if (!$class->CheckZone($zone));
    return 0 if (!$class->ZoneIsMaster($zone));

    my $zones = DnsServer->FetchZones();
    my $zone_index = 0;
    my $new_zone = {};
    foreach (@{$zones}) {
	if ($_->{'zone'} eq $zone) {
	    my $new_SOA = $_->{'soa'};
	    foreach my $key ('minimum', 'expiry', 'serial', 'retry', 'refresh', 'mail', 'server') {
		# changing current SOA with new values
		if (defined $SOA->{$key}) {
		    return 0 if (!$class->CheckSOARecord($key,$SOA->{$key}));
		    $new_SOA->{$key} = $SOA->{$key};
		}
	    }
	    $new_zone = $_;
	    # ttl is defined in another place
	    if (defined $SOA->{'ttl'}) {
		$new_zone->{'ttl'} = $SOA->{'ttl'};
	    }
	    $new_zone->{'soa'} = $new_SOA;
	    $new_zone->{'modified'} = 1;
	    last;
	}
	++$zone_index;
    }
    @{$zones}[$zone_index] = $new_zone;
    DnsServer->StoreZones($zones);

    return 1;
}

BEGIN{$TYPEINFO{GetReverseZoneNameForIP} = ["function","string","string"]};
sub GetReverseZoneNameForIP {
    my $class = shift;
    my $ip    = shift || '';

    my $zones = $class->GetZones();
    my @reversezones = ();
    foreach my $zone (keys %{$zones}) {
	if ($zones->{$zone}->{'type'} eq 'master' && $zone =~ /\.in-addr\.arpa$/) {
	    push @reversezones, $zone;
	}
    }

    if (scalar(@reversezones)==0) {
	return '';
    }

    my $arpaaddr = 'in-addr.arpa';
    my $matchingzone = '';
    foreach my $part (split(/\./, $ip)) {
	$arpaaddr = $part.'.'.$arpaaddr;
	foreach my $zone (@reversezones) {
	    $matchingzone = $zone if ($arpaaddr eq $zone);
	}
    }

    return $matchingzone;
}

BEGIN{$TYPEINFO{GetReverseIPforIPv4} = ["function","string","string"]};
sub GetReverseIPforIPv4 {
    my $class = shift;
    my $ipv4  = shift || '';

    my $reverseip = 'in-addr.arpa.';
    foreach my $part (split(/\./, $ipv4)) {
	$reverseip = $part.'.'.$reverseip;
    }

    return $reverseip;
}

# Adds an A host and its PTR ONLY if reverse zone exists
BEGIN{$TYPEINFO{AddHost} = ["function","boolean","string","string","string"]};
sub AddHost {
    my $class = shift;
    my $zone  = shift || '';
    my $key   = shift || '';
    my $value = shift || '';

    if (!$value) {
	# TRANSLATORS: Popup error message
	Report->Error(__("Host's IP cannot be empty."));
	return 0;
    }

    my $reversezone = $class->GetReverseZoneNameForIP($value) || '';
    if (!$reversezone) {
	# TRANSLATORS: Popup error message, No reverse zone for %1 record found,
	#   %2 is the hostname, %1 is the IPv4
	Report->Error(sformat(__("There is no reverse zone for '%1' administered by your DNS server.
Host name '%2' cannot be added."), $value, $key));
	return 0;
    }

    my $reverseip = $class->GetReverseIPforIPv4($value);

    # hostname MUST be in absolute form (for the reverse zone)
    if ($key !~ /\.$/) {
	$key .= '.'.$zone.'.';
    }
    return 0 if (!$class->AddZoneRR($zone,'A',$key,$value));
    return 0 if (!$class->AddZoneRR($reversezone,'PTR',$reverseip,$key));
    return 1;
}

# Removes an A host and also its PTR if reverse zone exists
BEGIN{$TYPEINFO{RemoveHost} = ["function","boolean","string","string","string"]};
sub RemoveHost {
    my $class = shift;
    my $zone  = shift || '';
    my $key   = shift || '';
    my $value = shift || '';

    if (!$value) {
	# TRANSLATORS: Popup error message
	Report->Error(__("Host's IP cannot be empty."));
	return 0;
    }

    my $reversezone = $class->GetReverseZoneNameForIP($value) || '';
    return 0 if (!$class->RemoveZoneRR($zone,'A',$key,$value));
    if ($reversezone) {
	# hostname MUST be in absolute form (in the reverse zone)
	if ($key !~ /\.$/) {
	    $key .= '.'.$zone.'.';
	}
	my $reverseip = $class->GetReverseIPforIPv4($value);
	return 0 if (!$class->RemoveZoneRR($reversezone,'PTR',$reverseip,$key));
    }

    return 1;
}

BEGIN{$TYPEINFO{GetZoneHosts} = ["function", ["list", ["map", "string", "string"]], "string"]};
sub GetZoneHosts {
    my $class      = shift;
    my $zone_only  = shift || '';


    my $zones = $class->GetZones();

    my $ptr_records = {};
    my @types = ('PTR');
    foreach my $zone (keys %{$zones}) {
	next if ($zones->{$zone}->{'type'} ne 'master');
	next if ($zone !~ /\.in-addr\.arpa$/);
	foreach my $record (@{$class->GetZoneRecords($zone, \@types)}) {
	    $record->{'value'} = $class->GetFullHostname($zone, $record->{'value'});
	    $record->{'key'}   = $class->GetFullHostname($zone, $record->{'key'});
	    # hostname/reverse_ip
	    $ptr_records->{$record->{'value'}.'/'.$record->{'key'}} = 1;
	}
    }
    
    my @hosts = ();
    @types = ('A');
    foreach my $zone (keys %{$zones}) {
	next if ($zone_only && $zone_only ne $zone);
	next if ($zones->{$zone}->{'type'} ne 'master');
	next if ($zone =~ /\.in-addr\.arpa$/);
	
	foreach my $record (@{$class->GetZoneRecords($zone, \@types)}) {
	    $record->{'key'}        = $class->GetFullHostname($zone, $record->{'key'});
	    $record->{'value'}      = $class->GetFullHostname($zone, $record->{'value'});
	    $record->{'reverse_ip'} = $class->GetReverseIPforIPv4($record->{'value'});

	    # hostname/reverse_ip
	    if (defined $ptr_records->{$record->{'key'}.'/'.$record->{'reverse_ip'}}) {
		push @hosts, {
		    'zone',    => $zone,
		    'hostname' => $record->{'key'},
		    'ip'       => $record->{'value'}
		};
	    }
	}
    }

    return \@hosts;
}

1;
