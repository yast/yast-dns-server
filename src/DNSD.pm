=head1 NAME

YaPI::DNSD - DNS server configuration API


=head1 PREFACE

This package is the public YaST2 API to configure the Bind version 9


=head1 SYNOPSIS

use YaPI::DNSD

$status = StopDnsService()

$status = StartDnsService()

$status = GetDnsServiceStatus()

$options = ReadGlobalOptions()

$ret = WriteGlobalOptions($options)

$zones = ReadZones()

$ret = WriteZones($zones)


=head1 DESCRIPTION

=over 2

=cut

package YaPI::DNSD;
use YaST::YCP;
YaST::YCP::Import ("DNSServer");
YaST::YCP::Import ("SCR");
YaST::YCP::Import ("Service");
YaST::YCP::Import ("SuSEFirewall");
YaST::YCP::Import ("NetworkDevices");
YaST::YCP::Import ("Progress");

#if(not defined do("YaPI.inc")) {
#    die "'$!' Can not include YaPI.inc";
#}

#######################################################
# temoprary solution end
#######################################################
our $VERSION="0.01";
our %TYPEINFO;

use strict;
use Errno qw(ENOENT);

#######################################################
# default and vhost API start
#######################################################

=item *
C<$status = StopDnsService();>

Immediatelly stops the DNS service. Returns nonzero if operation succeeded,
zero if operation failed.

EXAMPLE:

  my $status = StopDnsService ();
  if ($status == 0)
  {
    print "Stopping DNS server failed";
  }
  else
  {
    print "Stopping DNS server succeeded";
  }

=cut

BEGIN{$TYPEINFO{StopDnsService} = ["function", "boolean"];}
sub StopDnsService {
    return DnsServer->StopDnsService ();
}

=item *
C<$status = StartDnsService ();>

Immediatelly starts the DNS service. Returns nonzero if operation succeeded,
zero if operation failed.

EXAMPLE:

  my $status = StartDnsService ();
  if ($status == 0)
  {
    print "Starting DNS server failed";
  }
  else
  {
    print "Starting DNS server succeeded";
  }

=cut

BEGIN{$TYPEINFO{StartDnsService} = ["function", "boolean"];}
sub StartDndService {
    return DnsServer->StartDnsService ();
}

=item *
C<$status = GetDnsServiceStatus ();>

Check if DNS service is running. Returns nonzero if service is running,
zero otherwise.

EXAMPLE:

  my $status = GetDnsServiceStatus ();
  if ($status == 0)
  {
    print "DNS server is not running";
  }
  else
  {
    print "DNS server is running";
  }

=cut

BEGIN{$TYPEINFO{GetDnsServiceStatus} = ["function", "boolean"];}
sub GetDnsServiceStatus {
    return DnsServer->GetDnsServiceStatus ();
}

=item *
C<$options = ReadGlobalOptions ();>

Reads all global options of the DNS server.

Returns a list of hashes, each with keys "key" and "value", on success.
Returns undef on fail.

EXAMPLE:

  my $options = ReadGlobalOptions ();
  if (! defined ($options))
  {
    print "Reading options failed";
  }
  else
  {
    foreach my $option (@{$options}) {
      my $key = $option->{"key"};
      my $value = $option->{"value"};
      print "Have global option $key with value $value";
    }
  }

Prints all options adjusted to tbe specified declaration.


=cut

BEGIN{$TYPEINFO{ReadGlobalOptions} = ["function", ["list", ["map", "string","string"]]];}
sub ReadGlobalOptions {
    my $self = shift;

    Progress::off ();
    my $ret = DnsServer->Read ();
    my $options = undef;
    if ($ret)
    {
	$options = DnsServer->GetGlobalOptions ();
    }
    Progress::on ();
    return $options;
}

=item *
C<$ret = WriteGlobalOptions ($options);>

Writes all global options of the DNS server. The taken argument has the same
structure as return value of ReadGlobalOptions function.

Returns nonzero on success, zero on fail.

EXAMPLE: 

  my $options = {
    [
      "key" => "dump-file",
      "value" => "\"/var/log/named_dump.db\"",
    ],
    [
      "key" => "statistics-file",
      "value" => "\"/var/log/named.stats\"",
    ],
  }
  $success = WriteGlobalOptions ($options);

=cut

BEGIN{$TYPEINFO{WriteGlobalOptions} = ["function", "boolean", ["list", ["map", "string","string"]]];}
sub WriteGlobalOptions {
    my $self = shift;
    my $options = shift;

    Progress::off ();
    my $ret = DnsServer->Read ();
    $ret = $ret && DnsServer->SetGlobalOptions ($options);
    $ret = $ret && DnsServer->Write ();
    Progress::on ();
    return $ret;
}

=item *
C<$zones = ReadZones ();>

Reads all zones of the DNS server.

Retuns list of configured zones, each represented as a hash, on success.
The hash representing a zone is described below. On fail, returns undef.

EXAMPLE: 

  my $zones = ReadZones ();
  if (! defined ($zones))
  {
    print ("Could not read zones");
  }
  else
  {
    my $count = @{$zones};
    print "Maintaining $count zones";
  }

This prints the cound of zones maintained by the DNS server.

=cut

BEGIN{$TYPEINFO{ReadZones} = ["function", ["list", ["map", "string", "any"]]];}
sub ReadZones {
    my $self = shift;

    Progress::off ();
    my $ret = DnsServer->Read ();
    my $zones = undef;
    if ($ret)
    {
	$zones = DnsServer->FetchZones ();
    }
    Progress::on ();
    return $zones;
}

=item *
C<$ret = WriteZones ($zones);>

Writes all zones to the DNS server, removes zones that are not mentioned in the
argument. The structrure of the argument is clear from the example below.

Returns nonzero on success or zero on fail.

EXAMPLE:

  my $zones = [
    {
      'options' => [
        {
            'value' => 'master',
            'key' => 'type'
        },
        {
            'value' => '"localhost.zone"',
            'key' => 'file'
        }
      ],
      'zone' => 'localhost',
      'ttl' => '1W',
      'records' => [
        {
            'value' => '127.0.0.1',
            'type' => 'A',
            'key' => 'localhost.'
        },
        {
            'value' => '@',
            'type' => 'NS',
            'key' => 'localhost.'
        }
      ],
      'file' => 'localhost.zone',
      'type' => 'master',
      'soa' => {
        'minimum' => '1W',
        'expiry' => '6W',
        'serial' => 2004012701,
        'zone' => '@',
        'retry' => '4H',
        'refresh' => '2D',
        'mail' => 'root',
        'server' => '@'
      }
    }
  ];
  WriteZones ($zones);

This removes all DNS zones, and writes the specified zone
(in this case only one).

=cut

BEGIN{$TYPEINFO{WriteZones} = ["function", "boolean", ["list", ["map", "string", "any"]]];}
sub WriteZones {
    my $self = shift;
    my $zones = shift;

    Progress::off ();
    my $ret = DnsServer->Read ();
    $ret = $ret && DnsServer->StoreZones ($zones);
    $ret = $ret && DnsServer->Write ();
    Progress::on ();
    return $ret;
}

1;
