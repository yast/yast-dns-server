# encoding: utf-8

# File:	include/dns-server/helps.ycp
# Package:	Configuration of dns-server
# Summary:	Help texts of all the dialogs
# Authors:	Jiri Srain <jiri.srain@suse.cz>,
#		Lukas Ocilka <lukas.ocilka@suse.cz>
#
# $Id$
module Yast
  module DnsServerHelpsInclude
    def initialize_dns_server_helps(include_target)
      textdomain "dns-server"

      Yast.import "DnsServer"

      # All helps are here
      @HELPS = {
        # Read dialog help 1/2
        "read"                        => _(
          "<p><b><big>Initializing DNS Server Configuration</big></b><br>\nPlease wait...<br></p>"
        ) +
          # Read dialog help 2/2
          _(
            "<p><b><big>Aborting Initialization</big></b><br>\nSafely abort the configuration utility by pressing <b>Abort</b> now.</p>"
          ),
        # Write dialog help 1/2
        "write"                       => _(
          "<p><b><big>Saving DNS Server Configuration</big></b><br>\nPlease wait...<br></p>"
        ) +
          # Write dialog help 2/2
          _(
            "<p><b><big>Aborting Saving</big></b><br>\n" +
              "Abort the save procedure by pressing <b>Abort</b>.\n" +
              "An additional dialog informs you whether it is safe to do so.</p>"
          ),
        # main dialog
        # help 1/4
        "start"                       => _(
          "<p><b><big>Start DNS Server</big></b><br>\n" +
            "To run the DNS server every time your computer is started, set\n" +
            "<b>Start DNS Server</b>.</p>"
        ),
        # help 2/4
        "chroot"                      => _(
          "<p><b><big>Chroot Jail</big></b><br>\n" +
            "To run the DNS server in chroot jail, set\n" +
            "<b>Run DNS Server in Chroot Jail</b>. Starting any daemon in a chroot jail\n" +
            "is more secure and strongly recommended.</p>"
        ),
        # help 3/4
        "zones"                       => _(
          "<p><b><big>Editing DNS Zones</big></b><br>\n" +
            "To edit settings of a DNS zone, choose the appropriate\n" +
            "entry of the table and click <B>Edit</B>.\n" +
            "To add a new DNS zone, use <B>Add</B>. To remove\n" +
            "a configured DNS zone, select it and click <B>Delete</B>.</P>"
        ),
        # help 4/4
        "adv_mbutton"                 => _(
          "<p><b><big>Advanced Functions</big></b><br>\n" +
            "To edit global options,\n" +
            "adjust firewall settings,\n" +
            "manage the TSIG keys for dynamic updates of the zones,\n" +
            "or display the log of the DNS server,\n" +
            "use <b>Advanced</b>.</p>"
        ),
        # zone dialog
        # help 1/5
        "zone_name"                   => _(
          "<p><b><big>Zone Name</big></b><br>\nEnter the name of the zone (domain) in <b>Zone Name</b>.</p>"
        ),
        # help 2/5, alt. 1
        "allow_ddns"                  => _(
          "<p><b><big>Dynamic DNS Zone Updates</big></b><br>\n" +
            "The zone can be updated automatically, usually because of dynamically\n" +
            "assigned IP addresses by DHCP server. To allow DDNS updates, set\n" +
            "<b>Allow Dynamic Updates</b> and the <b>TSIG Key</b>\n" +
            "to use for authentication. The key must be the same for\n" +
            "both DHCP and DNS servers.</p>"
        ),
        # help 3/5, only for alt. 1
        "master_zone"                 => _(
          "<p><b><big>Editing a DNS Zone</big></b><br>\n" +
            "To edit the zone settings, choose the appropriate\n" +
            "entry of the table then click <b>Edit</b>.</p>"
        ) +
          # help 4/5, only for alt. 1
          _(
            "<p>To add a new record to the zone, click <b>Add</b>. To remove\na record, select it and click <b>Delete</b>.</p>"
          ),
        # help 5/5, only for alt. 1
        "soa_button"                  => _(
          "<p><b><big>SOA Record</big></b><br>\n" +
            "To edit the SOA (Start of Authority) record of the zone, click\n" +
            "<b>Edit SOA</b>.</p>"
        ),
        # help 2/5 alt. 2
        "zone_masters"                => _(
          "<p><b><big>Master Servers</big></b><br>\n" +
            "Set the IP addresses of the master name servers for this zone. Use <b>Add</b>\n" +
            "to add a new master name server. Select an existing one then click <b>Delete</b>\n" +
            "to remove an existing one.</p>"
        ),
        # help 1/2
        "zone_type"                   => _(
          "<p><b><big>Zone Type</big></b><br>\n" +
            "To make this name server the primary source of the data of the zone,\n" +
            "select <b>Master</b>. To make it the secondary name server, select <b>Slave</b>\n" +
            "or <b>Stub</b>, so the data of the zone will be mirrored from the master\n" +
            "server.</p>"
        ),
        # help 2/2
        "zone_direction"              => _(
          "<p><b><big>Zone Direction</big></b><br>\n" +
            "DNS is used both for translating from domain names to IP addresses and back.\n" +
            "Select if this zone will be used to translate from domain names to IP\n" +
            "addresses (<b>Forward</b>) or from IP addresses to domain names\n" +
            "(<b>Reverse</b>).</p>\n"
        ),
        # firewall dialog
        # help text 1/2
        "iface_classes"               => _(
          "<p><b><big>Interface Classes</big></b><br>\n" +
            "Select which interface classes should have access to the DNS server. The\n" +
            "interface classes are defined in the firewall configuration component.</p>\n"
        ),
        # help text 2/2
        "adapt_firewall"              => _(
          "<p><b><big>Adapting Firewall Settings</big></b><br>\n" +
            "To adapt the firewall settings so that the DNS server can be accessed\n" +
            "via all network interfaces to which it listens, check\n" +
            "<b>Adapt Firewall Settings</b>.</p>\n"
        ),
        # soa dialog
        # help text 1/9
        "soa"                         => _(
          "<p><b><big>SOA Record Configuration</big></b><br>\nSet the entries of the SOA record.</p>"
        ) +
          # help text 2/9 - TTL
          _(
            "<p><b>$TTL</b> specifies the time to live for all records in the\nzone that do not have an explicit TTL.</p>"
          ) +
          # help text 3/9 - Primary source
          _(
            "<p><b>Primary Source</b> must contain the fully qualified domain name\nof the primary name server.</p>"
          ) +
          # help text 4/9 - Administrator's mail
          _(
            "<p><b>Administrator's Mail</b> must contain the e-mail address of\nthe administrator responsible for the zone.</p>\n"
          ) +
          # help text 5/9 - Serial
          _(
            "<p><b>Serial</b> number is used for determining if the zone has changed on\n" +
              "the master servers (so that slave servers do not always need to synchronize the\n" +
              "entire zone).</p>\n"
          ) +
          # help text 6/9 - Refresh
          _(
            "<p><b>Refresh</b> sets how often the zone should be synchronized from\nmaster name server to slave name servers.</p>"
          ) +
          # help text 7/9 - Retry
          _(
            "<p><b>Retry</b> sets how often slave servers try to synchronize\nthe zone from the master server if synchronization fails.</p>"
          ) +
          # help text 8/9 - Expiry
          _(
            "<p><b>Expiry</b> means the period after which the zone expires on slave\n" +
              "servers and slave servers stop answering replies until it is synchronized.\n" +
              "</p>"
          ) +
          # help text 9/9 - Minimum
          _(
            "<p><b>Minimum</b> sets for how long the slave servers should cache\nnegative answers (name resolution failed).</p>"
          ),
        # ddns keys dialog
        # help text 1/1
        "ddns_keys"                   => _(
          "<p><b><big>TSIG Key Management</big></b><br>\n" +
            "Define TSIG keys used for dynamic zone updates.\n" +
            "To add a new TSIG key, use the \n" +
            "<b>File Name</b> text field or the <b>Browse</b> button then click <b>Add</b>.\n" +
            "To delete an existing TSIG key, select it in the list and click <b>Delete</b>.\n" +
            "</p>"
        ),
        # Expert Mode Configuration - Start Up 1/3
        "start_up"                    => _(
          "<p><b><big>Booting</big></b><br>\n" +
            "To start the DNS server every time your computer is booted, set\n" +
            "<b>On</b>. Otherwise set <b>Off</b>.</p> "
        ) +
          (DnsServer.ExpertUI ?
            # Expert Mode Configuration - Start Up 1/3
            _(
              "<p><b><big>LDAP Support</big></b><br>\n" +
                "To store the DNS zones in LDAP instead of native configuration files,\n" +
                "set <b>LDAP Support Active</b>.</p>"
            ) :
            "") +
          # Expert Mode Configuration - Start Up 3/3
          _(
            "<p><b><big>Switch On or Off</big></b><br>\n" +
              "To start or stop the DNS server immediately, use \n" +
              "<b>Start DNS Server Now</b> or\n" +
              "<b>Stop DNS Server Now</b>.</p>\n"
          ),
        # TODO
        "status"                  => _(
          "<p><b><big>TODO</big></b><br>\n" +
            "TODO\n"
        ),
        # Expert Mode Configuration - Forwarders 1/3
        "forwarders"                  => _(
          "<p><b><big>Forwarders</big></b><br>\n" +
            "Forwarders are DNS servers to which your DNS server should send queries\n" +
            "it cannot answer.</p>\n"
        ) +
          # Expert Mode Configuration - Forwarders 2/3
          # _("<p>To ask forwarders during name resolution and in case of fail do full
          # DNS lookup, set <b>Forward First</b>. To ask forwarders only, set
          # <b>Forwarders Only</b>. To do full DNS lookup always, do not check any
          # of these check boxes.</p>
          # ") +

          # Expert Mode Configuration - Forwarders 3/3
          _(
            "<p>To add a new forwarder, set its <b>IP Address</b> and click <b>Add</b>.\nTo delete a configured forwarder, select it and click <b>Delete</b>.</p>"
          ),
        # Expert Mode Configuration - Basic Options 1/2
        "basic_options"               => _(
          "<p><b><big>Edit DNS Server Options</big></b><br>\nUse this dialog to edit options of the DNS server.</p>"
        ) +
          # Expert Mode Configuration - Basic Options 2/3
          _(
            "<p>To add new options, select the <b>Option</b>,\n" +
              "enter its <b>Value</b>, and click <b>Add</b>.</p>\n" +
              "<p>To modify a configured option, select it in the table,\n" +
              "change the <b>Value</b>, and click <b>Change</b>.</p>\n"
          ) +
          # Expert Mode Configuration - Basic Options 3/3
          _("<p>To remove an option, select it and click <b>Delete</b>.</p>"),
        # Expert Mode Configuration - Logging 1/3
        "logging"                     => _(
          "<p><b><big>Logging</big></b><br>\nUse this dialog to define various options of the DNS server logging.</p>"
        ) +
          # Expert Mode Configuration - Logging 2/3
          _(
            "<p>\n" +
              "Select <b>Log to System Log</b> to save DNS server log messages to the system log. \n" +
              "To save the DNS server log messages to a separate file, select \n" +
              "<b>Log to File</b> and set the <b>Filename</b> to which to save the log and \n" +
              "the <b>Maximum Size</b> of the log file.\n" +
              "The DNS server automatically rotates the log files. Use <b>Maximum Versions</b>\n" +
              "to specify how many log files should be saved.</p>\n"
          ) +
          # Expert Mode Configuration - Logging 3/3
          _(
            "<p>In <b>Additional Logging</b>,\n" +
              "set which actions should be logged. Common actions are always logged.\n" +
              "<b>Log All DNS Queries</b> logs all queries from clients to the DNS server.\n" +
              "<b>Log Zone Updates</b> logs when DNS has been updated.\n" +
              "<b>Log Zone Transfers</b> logs when zone is completely transferred to the \n" +
              "secondary\n" +
              "name server.</p>\n"
          ),
        # Expert Mode Configuration - ACLs 1/2
        "acls"                        => _(
          "<p><b><big>ACLs</big></b><br>\n" +
            "In this dialog, define access control lists to control\n" +
            "access to zones.</p>\n"
        ) +
          # Expert Mode Configuration - ACLs 2/2
          _(
            "<p>To add a new ACL entry, just enter the option's <b>Name</b>\n" +
              "and <b>Value</b> then click <b>Add</b>.  To remove an \n" +
              "ACL entry, select it and click <b>Delete</b>.</p>\n"
          ),
        # Expert Mode Configuration - Keys 1/3
        "keys"                        => _(
          "<p><b><big>TSIG Keys</big></b><br>\n" +
            "TSIG keys are used for authentication when remotely\n" +
            "changing the configuration of the DNS server. This is needed\n" +
            "for the dynamic updates of DNS zones (DDNS).</p>\n"
        ) +
          # Expert Mode Configuration - Keys 2/3
          _(
            "<p>To add an already created key, set the <b>Filename</b>\n" +
              "(or use the <b>Browse</b> button to select it) and click <b>Add</b>.\n" +
              "To generate a new key, enter the <b>Filename</b> and the <b>Key ID</b>\n" +
              "then click <b>Generate</b>. The new key will be generated and also added.</p>\n"
          ) +
          # Expert Mode Configuration - Keys 3/3
          _(
            "<p>To remove an existing key, select it and\nclick <b>Delete</b>.</p>"
          ),
        # Expert Mode Configuration - Zones #1
        "zones"                       => Ops.add(
          Ops.add(
            _(
              "<p><b><big>DNS Zones</big></b><br>\nUse this dialog to manage the DNS zones.</p>\n"
            ) +
              # Expert Mode Configuration - Zones #2
              _(
                "<p>To add a new zone, enter its <b>Zone Name</b>, select the <b>Zone Type</b>,\nand click <b>Add</b>.</p>\n"
              ) +
              # Expert Mode Configuration - Zones #3
              _(
                "<p>To add a new IPv4 reverse zone, enter a part of the reverse IPv4 address followed by\n" +
                  "<tt>.in-addr.arpa</tt> as its <b>Zone Name</b> (for example, zone name\n" +
                  "<tt>0.168.192.in-addr.arpa</tt> for network <tt>192.168.0.0/24</tt>), select\n" +
                  "the <b>Zone Type</b>, and click <b>Add</b>.</p>\n"
              ),
            # Expert Mode Configuration - Zones #4
            # %1, %2, %3, and %4 are replaced with examples
            Builtins.sformat(
              _(
                "<p>To add a new IPv6 reverse zone, enter a part of the reverse IPv6 address followed by\n" +
                  "<tt>%1</tt> as its <b>Zone Name</b>. Several formats for entering the zone name are\n" +
                  "supported: Standard form: <tt>%2</tt>;\n" +
                  "Forward form: <tt>%3</tt>;\n" +
                  "Forward form without netmask bits: <tt>%4</tt>\n" +
                  "(by default <tt>64</tt> netmask bits are used).</p>\n"
              ),
              ".ip6.arpa.",
              "4.5.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa.",
              "2001:db8:0:54::/64",
              "2001:db8:0:54::"
            )
          ),
          # Expert Mode Configuration - Zones #5
          _(
            "<p>To modify settings for a zone, such as zone transport and name and\n" +
              "mail servers, select it, and click <b>Edit</b>.\n" +
              "To remove a configured zone, select it and click <b>Delete</b>.</p>\n"
          )
        ),
        "zone_editor_basics"          => (DnsServer.ExpertUI ?
          # Zone Editor - Help for tab - Basics  1/3
          _(
            "<p><b><big>DDNS and Zone Transport</big></b><br>\n" +
              "Use this dialog to change dynamic DNS settings of the zone and control access\n" +
              "to the zone.</p>\n"
          ) :
          "") +
          (DnsServer.ExpertUI ?
            # Zone Editor - Help for tab - Basics  2/3
            _(
              "<p>\n" +
                "To allow dynamic updates of the zone, set <b>Allow Dynamic Updates</b>\n" +
                "and select the <b>TSIG Key</b>. At least one TSIG key must be defined\n" +
                "before the zone can be updated dynamically.</p>\n"
            ) :
            "") +
          # Zone Editor - Help for tab - Basics  3/3
          _(
            "<p>\n" +
              "To allow transports of the zone, set <b>Enable Zone Transport</b>\n" +
              "and select the <b>ACLs</b> to check when a remote host\n" +
              "attempts to transfer the zone. At least one ACL must be defined\n" +
              "to allow zone transports.</p>"
          ) +
          # Zone Editor - Help
          _(
            "<p>\n" +
              "Reverse zone records can be generated from another master zone.\n" +
              "Select the <b>Automatically Generate Records From</b>\n" +
              "check-box and choose the zone to generate the records from.</p>\n"
          ) +
          # Zone Editor - Help
          _(
            "<p>\n" +
              "If this is not a reverse zone, you can see which zones are generated\n" +
              "from the current on in the <b>Connected Reverse Zones</b> field.</p>"
          ),
        # Zone Editor - Help for tab - Name Servers
        "zone_editor_nameservers"     => _(
          "<p><b><big>NS Records</big></b><br>\n" +
            "To add a new name server, enter the name server address and click <b>Add</b>.\n" +
            "To remove one of the listed name servers, select it and click\n" +
            "<b>Delete</b>.</p>\n"
        ),
        # Zone Editor - Help for tab - Mail Servers
        "zone_editor_mailservers"     => _(
          "<p><b><big>MX Records</big></b><br>\n" +
            "To add a new mail server, enter the <b>Address</b> and <b>Priority</b>\n" +
            "and click <b>Add</b>.\n" +
            "To remove one of the listed mail servers, select it and click\n" +
            "<b>Delete</b>.</p>\n"
        ),
        # Zone Editor - Help for tab - Zone (SOA) 1/7
        "zone_editor_soa"             => _(
          "<p><b><big>SOA Record Configuration</big></b><br>\nSet the entries of the SOA record.</p>"
        ) +
          # Zone Editor - Help for tab - Zone (SOA) 2/7
          _(
            "<p><b>Serial</b> is the number used for determining if the zone has \n" +
              "changed on\n" +
              "the master servers (then slave servers do not always need to synchronize the\n" +
              "entire zone).</p>\n"
          ) +
          # Zone Editor - Help for tab - Zone (SOA) 3/7
          _(
            "<p><b>TTL</b> specifies the time to live for all records in the\nzone that do not have an explicit TTL.</p>"
          ) +
          # Zone Editor - Help for tab - Zone (SOA) 4/7
          _(
            "<p><b>Refresh</b> sets how often the zone should be synchronized from\nmaster name server to slave name servers.</p>"
          ) +
          # Zone Editor - Help for tab - Zone (SOA) 5/7
          _(
            "<p><b>Retry</b> sets how often slave servers try to synchronize\nthe zone from the master server if synchronization fails.</p>"
          ) +
          # Zone Editor - Help for tab - Zone (SOA) 6/7
          _(
            "<p><b>Expiration</b> means the period after which the zone expires on slave\n" +
              "servers and slave servers stop answering replies until it is synchronized.\n" +
              "</p>"
          ) +
          # Zone Editor - Help for tab - Zone (SOA) 7/7
          _(
            "<p><b>Minimum</b> sets for how long the slave servers should cache\nnegative answers (name resolution failed).</p>"
          ),
        # Zone Editor - Help for tab - Records 1/7  or 1/5
        "zone_editor_records"         => _(
          "<p><b><big>Records</big></b><br>\n" +
            "In this dialog, edit the resource records of the zone. To add new resource\n" +
            "records, set the <b>Record Key</b>, <b>Type</b>, and <b>Value</b> then\n" +
            "click <b>Add</b>.</p>"
        ) +
          # Zone Editor - Help for tab - Records 2/7 or 2/5
          _(
            "<p>To change an existing record, select it, modify the desired entries,\n" +
              "and click <b>Change</b>. To delete a record, select it and click\n" +
              "<b>Delete</b>.</p>"
          ) +
          # Zone Editor - Help for tab - Records 3/7 or 3/5
          _(
            "<p>\nEach type of record has its own syntax defined in the RFC.</p>\n"
          ),
        # Zone Editor - Help for tab - Records 4/7 (alt. 1)
        "zone_editor_records_forward" => _(
          "<p><b>A: Domain Name Translation</b>:\n" +
            "<b>Record Key</b> is a hostname without domain or a fully qualified \n" +
            "hostname followed by a dot.\n" +
            " <b>Value</b> is an IP address.</p>"
        ) +
          # Zone Editor - Help for tab - Records 5/7 (alt. 1)
          _(
            "<p><b>CNAME: Alias for Domain Name</b>:\n" +
              "<b>Record Key</b> is a hostname relative to the current zone or a fully\n" +
              "qualified hostname followed by a dot.\n" +
              "<b>Value</b> is a hostname relative to the current zone or a fully\n" +
              "qualified hostname followed by a dot. It must be represented by\n" +
              "an A record.</p>\n"
          ) +
          # Zone Editor - Help for tab - Records 6/7 (alt. 1)
          _(
            "<p><b>NS: Name Server</b>:\n" +
              "<b>Record Key</b> is a zone name relative to the current zone or an absolute\n" +
              "domain name followed by a dot.\n" +
              "<b>Value</b> is a hostname relative to the current zone or fully qualified\n" +
              "hostname followed by a dot.  It must be represented by an A record.</p>\n"
          ) +
          # Zone Editor - Help for tab - Records 7/7 (alt. 1)
          _(
            "<p><b>MX: Mail Relay</b>:\n" +
              "<b>Record Key</b> is a hostname or zone name relative to the current zone\n" +
              "or an absolute hostname or zone name followed by a dot.\n" +
              "<b>Value</b> is a hostname relative to the current zone or fully qualified\n" +
              "hostname followed by a dot.  It must be represented by an A record.</p>\n"
          ),
        # Zone Editor - Help for tab - Records 4/5 (alt. 2)
        "zone_editor_records_reverse" => _(
          "<p><b>PTR: Reverse Translation</b>:\n" +
            "<b>Record Key</b> is a full reverse zone name (derived from the IP address)\n" +
            "followed by a dot\n" +
            "(such as <tt>1.0.168.192.in-addr.arpa.</tt> for IP address <tt>192.168.0.1</tt>)\n" +
            " or a part of reverse zone name relative to the current zone\n" +
            "(such as <tt>1</tt> for IP address <tt>192.168.0.1</tt> in zone\n" +
            "<tt>0.168.192.in-addr.arpa.</tt>).\n" +
            "<b>Value</b> is a fully qualified hostname followed by a dot.</p>\n"
        ) +
          # Zone Editor - Help for tab - Records 5/5 (alt. 2)
          _(
            "<p><b>NS: Name Server</b>:\n" +
              "<b>Record Key</b> is a zone name relative to the current zone or an absolute\n" +
              "domain name followed by a dot.\n" +
              "<b>Value</b> is a hostname relative to the current zone or fully qualified\n" +
              "hostname followed by a dot.  It must be represented by an A record.</p>\n"
          ),
        # Final step of the installation wizard - 1/5
        "installwizard_step3"         => _(
          "<p><b><big>Finishing the Configuration</big></b></p>\n<p>Check the entered settings before finishing the configuration.</p> \n"
        ) +
          # Final step of the installation wizard - 2/5
          _(
            "<p>Select <b>Open Port in Firewall</b> to adapt the\nSuSEfirewall2 settings to allow all connections to your DNS server.</p>"
          ) +
          # Final step of the installation wizard - 3/5
          _(
            "<p>\n" +
              "To start the DNS server every time your computer is booted, set the \n" +
              "start-up behavior to <b>On</b>. Otherwise set it to <b>Off</b>.</p> \n"
          ) +
          (DnsServer.ExpertUI ?
            # Final step of the installation wizard - 4/5
            _(
              "<p>\n" +
                "To store the DNS zones in LDAP instead of native configuration files,\n" +
                "set <b>LDAP Support Active</b>.</p>"
            ) :
            "") +
          # Final step of the installation wizard - 5/5
          _(
            "<p>\n" +
              "To enter the expert mode of the DNS server configuration, click\n" +
              "<b>DNS Server Expert Configuration</b>.</p>"
          ),
        # slave zone help text 1/2
        "slave_zone"                  => _(
          "<p><big><b>Slave DNS Zone</b></big><br>\n" +
            "Each slave zone must have the master name server defined. Use\n" +
            "<b>Master DNS Server IP</b> to define the master name server.</p>"
        ) +
          # slave zone help text 2/2
          _(
            "<p><big><b>Zone Transport</b></big><br>\n" +
              "To allow transports of the zone, set <b>Enable Zone Transport</b>\n" +
              "and select the <b>ACLs</b> to check when a remote host\n" +
              "attempts to transfer the zone. At least one ACL must be defined\n" +
              "to allow zone transports.</p>"
          ),
        # forward zone help text 1/2
        "forward_zone"                => _(
          "<p><big><b>Forward DNS Zone</b></big><br>\n" +
            "This type of DNS zone only forwards DNS queries to forwarders\n" +
            "defined in it.</p>"
        ) +
          # forward zone help text 2/2
          _(
            "<p>If there are no forwarders defined, all DNS queries\n" +
              "for the respective zone are denied, because there is no DNS\n" +
              "server to which that query should be forwarded.</p>"
          )
      } 

      # EOF
    end
  end
end
