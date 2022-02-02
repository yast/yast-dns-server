# encoding: utf-8

# Copyright 2004, Novell, Inc.  All rights reserved.
#
# File:	dns-server/cmdline.ycp
# Package:	DNS Server Configuration
# Summary:	Command Line for YaST2 DNS Server
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# $Id$
module Yast
  module DnsServerCmdlineInclude
    def initialize_dns_server_cmdline(include_target)
      textdomain "dns-server"

      Yast.import "CommandLine"
      Yast.import "String"
      Yast.import "DnsServer"
      Yast.import "DnsServerAPI"

      @cmdline = {
        "id"         => "dns-server",
        # TRANSLATORS: commandline general name of the module in help
        "help"       => _(
          "DNS server configuration"
        ),
        "initialize" => fun_ref(DnsServer.method(:Read), "boolean ()"),
        "finish"     => fun_ref(DnsServer.method(:Write), "boolean ()"),
        "actions"    => {
          "startup"    => {
            "handler" => fun_ref(method(:DNSHandlerStartup), "boolean (map)"),
            "help"    => _("Start-up settings"),
            "example" => ["startup show", "startup atboot; startup manual"]
          },
          "forwarders" => {
            "handler" => fun_ref(method(:DNSHandlerForwarders), "boolean (map)"),
            # TRANSLATORS: commandline short help for command
            "help"    => _(
              "DNS forwarders"
            ),
            "example" => [
              "forwarders show",
              "forwarders add ip=125.11.235.1",
              "forwarders remove ip=44.82.1.12"
            ]
          },
          "logging"    => {
            "handler" => fun_ref(method(:DNSHandlerLogging), "boolean (map)"),
            # TRANSLATORS: commandline short help for command
            "help"    => _(
              "Logging settings"
            ),
            "example" => [
              "logging show",
              "logging set updates=no transfers=yes",
              "logging destination=syslog",
              "logging destination=file maxsize=0 file=/var/log/named.log maxversions=0"
            ]
          },
          "zones"      => {
            "handler" => fun_ref(method(:DNSHandlerZones), "boolean (map)"),
            # TRANSLATORS: commandline short help for command
            "help"    => _(
              "DNS zones"
            ),
            "example" => [
              "zones show",
              "zones add name=example.org zonetype=primary",
              "zones add name=example.com zonetype=secondary primaryserver=192.168.0.1",
              "zones add name=example.com zonetype=forward forwarders=192.168.0.1,192.168.0.2",
              "zones remove name=example.org",
              "zones set name=example.com primaryserver=192.168.10.1",
              "zones set name=example.com forwarders=192.168.0.3"
            ]
          },
          "acls"       => {
            "handler"  => fun_ref(method(:DNSHandlerACLs), "boolean (map)"),
            # TRANSLATORS: commandline short help for command
            "help"     => _(
              "Access control lists"
            ),
            "examples" => ["acls show"]
          },
          "transport"  => {
            "handler"  => fun_ref(method(:DNSHandlerTransport), "boolean (map)"),
            # TRANSLATORS: commandline short help for command
            "help"     => _(
              "Zone transport rules"
            ),
            "examples" => [
              "transport show",
              "transport show zone=example.com",
              "transport zone=master.com enable=localnets"
            ]
          },
          "nameserver" => {
            "handler" => fun_ref(
              method(:DNSHandlerNameServers),
              "boolean (map)"
            ),
            # TRANSLATORS: commandline short help for command, base cmdline command
            "help"    => _(
              "Zone name servers"
            ),
            "example" => [
              "nameserver show",
              "nameserver show zone=example.com",
              "nameserver add zone=example.com ns=ns1",
              "nameserver add zone=example.com ns=ns2.example.com.",
              "nameserver remove zone=example.com ns=ns2"
            ]
          },
          "mailserver" => {
            "handler" => fun_ref(
              method(:DNSHandlerMailServers),
              "boolean (map)"
            ),
            # TRANSLATORS: commandline short help for command, base cmdline command
            "help"    => _(
              "Zone mail servers"
            ),
            "example" => [
              "mailserver show",
              "mailserver show zone=example.org",
              "mailserver add zone=example.org mx=mx1 priority=100",
              "mailserver add zone=example.org mx=mx2.example.com. priority=99",
              "mailserver remove zone=example.org mx=mx2.example.com. priority=99"
            ]
          },
          "soa"        => {
            "handler" => fun_ref(method(:DNSHandlerSOA), "boolean (map)"),
            # TRANSLATORS: commandline short help for command, base cmdline command
            "help"    => _(
              "Start of authority (SOA)"
            ),
            "example" => [
              "soa show zone=example.org",
              "soa set zone=example.org serial=2006081623 ttl=2D3H20S",
              "soa set zone=example.org serial=2006081624 expiry=1W retry=180"
            ]
          },
          "dnsrecord"  => {
            "handler" => fun_ref(
              method(:DNSHandlerResourceRecords),
              "boolean (map)"
            ),
            # TRANSLATORS: commandline short help for command, base cmdline command
            "help"    => _(
              "Zone resource records, such as A, CNAME, NS, MX, or PTR"
            ),
            "example" => [
              "dnsrecord show",
              "dnsrecord show zone=example.org",
              "dnsrecord show zone=example.org type=A",
              "dnsrecord add zone=example.org query=office.example.org. type=NS value=ns3",
              "dnsrecord add zone=example.org query=ns3 type=CNAME value=server3.anywhere.net.",
              "dnsrecord remove zone=example.org query=office type=A value=192.168.32.1"
            ]
          },
          "host"       => {
            "handler" => fun_ref(
              method(:DNSHandlerHostRecords),
              "boolean (map)"
            ),
            # TRANSLATORS: commandline short help for command, base cmdline command, A is record type
            "help"    => _(
              "Handles A and corresponding PTR record at once"
            ),
            "example" => [
              "host show",
              "host show zone=example.org",
              "host add zone=master.com hostname=examplehost.example.org. ip=192.168.0.201",
              "host remove zone=master.com hostname=examplehost ip=192.168.0.201"
            ]
          }
        },
        "options"    => {
          "show"         => {
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Show current settings"
            )
          },
          "atboot"       => {
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Start DNS server in the boot process"
            )
          },
          "manual"       => {
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Start DNS server manually"
            )
          },
          "add"          => {
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Add a new record"
            )
          },
          "remove"       => {
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Remove a record"
            )
          },
          "ip"           => {
            "type" => "ip4",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "IPv4 address"
            )
          },
          "destination"  => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Logging destination (syslog|file)"
            )
          },
          "set"          => {
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Set option"
            )
          },
          "file"         => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Filename for logging (full path)"
            )
          },
          "maxsize"      => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Maximum log size [0-9]+(KMG)*"
            )
          },
          "maxversions"  => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Maximum number of versions for rotation, '0' means no rotation"
            )
          },
          "name"         => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Zone name"
            )
          },
          "zonetype"     => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Zone type, primary or secondary"
            )
          },
          "masterserver" => {
            "type" => "ip4",
            # TRANSLATORS: commandline short help for command
            # TRANSLATORS: obsolete option, primaryserver should be used instead
            "help" => _(
              "DNS zone master server"
            )
          },
          "primaryserver" => {
            "type" => "ip4",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "DNS zone master server"
            )
          },
          "zone"         => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Zone name"
            )
          },
          "enable"       => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Enable option"
            )
          },
          "disable"      => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Disable option"
            )
          },
          "ns"           => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Name server (in fully qualified format finished with a dot or relative name)"
            )
          },
          "mx"           => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Mail server (in fully qualified format finished with a dot or relative name)"
            )
          },
          "priority"     => {
            "type" => "integer",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Mail server priority (number from 0 to 65535)"
            )
          },
          "serial"       => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Serial number of zone update"
            )
          },
          "ttl"          => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "General time to live of records in zone"
            )
          },
          "refresh"      => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "An interval before the zone records should be refreshed"
            )
          },
          "retry"        => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Interval between retries of failed refresh"
            )
          },
          "expiry"       => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Interval after which zone records are no longer authoritative"
            )
          },
          "minimum"      => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command, TTL is DNS-Specific (Time to Live), shouldn't be translated
            "help" => _(
              "Minimum TTL that should be exported with records in this zone"
            )
          },
          "type"         => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command, Types are DNS-Specific, cannot be translated
            "help" => _(
              "DNS resource record type, such as A, CNAME, NS, MX, or PTR"
            )
          },
          "query"        => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command, DNS query is a question for value when we have a /key/ and type, ('A' record for 'example.org'? -> 192.0.34.166)
            "help" => _(
              "DNS query, such as example.org for A record"
            )
          },
          "value"        => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "DNS resource record value, such as 192.0.34.166 for example.org's A record"
            )
          },
          "hostname"     => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Hostname for the DNS record"
            )
          },
          "queries"      => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command, %1 are possible untranlatable parameters "(yes|no)"
            "help" => Builtins.sformat(
              _("Log named queries %1"),
              "(yes|no)"
            )
          },
          "updates"      => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command, %1 are possible untranlatable parameters "(yes|no)"
            "help" => Builtins.sformat(
              _("Log zone updates %1"),
              "(yes|no)"
            )
          },
          "transfers"    => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command, %1 are possible untranlatable parameters "(yes|no)"
            "help" => Builtins.sformat(
              _("Log zone transfers %1"),
              "(yes|no)"
            )
          },
          "forwarders"   => {
            "type" => "string",
            # TRANSLATORS: commandline short help for command
            "help" => _(
              "Comma-separated list of zone forwarders"
            )
          }
        },
        "mappings"   => {
          "startup"    => ["show", "atboot", "manual"],
          "forwarders" => ["show", "add", "remove", "ip"],
          "logging"    => [
            "show",
            "destination",
            "set",
            "file",
            "maxsize",
            "maxversions",
            "queries",
            "transfers",
            "updates"
          ],
          "zones"      => [
            "show",
            "add",
            "remove",
            "set",
            "name",
            "masterserver",
            "primaryserver",
            "zonetype",
            "forwarders"
          ],
          "acls"       => ["show"],
          "transport"  => ["show", "enable", "disable", "zone"],
          "nameserver" => ["show", "add", "remove", "ns", "zone"],
          "mailserver" => ["show", "add", "remove", "mx", "zone", "priority"],
          "soa"        => [
            "show",
            "set",
            "zone",
            "serial",
            "ttl",
            "refresh",
            "retry",
            "expiry",
            "minimum"
          ],
          "dnsrecord"  => [
            "show",
            "add",
            "remove",
            "zone",
            "query",
            "type",
            "value"
          ],
          "host"       => ["show", "add", "remove", "zone", "hostname", "ip"]
        }
      }

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone(
        Builtins.sformat("Starting CommandLine with parameters %1", WFM.Args)
      )
      CommandLine.Run(@cmdline)
      Builtins.y2milestone("----------------------------------------") 

      # EOF
    end

    # Wizard Screen function formats and prints unifyied commandline screen
    def ScreenWizard(header, content)
      CommandLine.Print("")
      CommandLine.Print(String.UnderlinedHeader(header, 0))
      CommandLine.Print("")
      if content != ""
        CommandLine.Print(content)
        CommandLine.Print("")
      end

      nil
    end

    # Function prints commandline error about missing parameter
    def Missing(missing_parameter)
      CommandLine.Error(
        Builtins.sformat(
          # TRANSLATORS: command line error message, %1 is a missing required parameter
          _("Parameter %1 is required."),
          missing_parameter
        )
      )

      nil
    end

    # Function prints commandline error about unknown value for option
    def UnknownValue(cmdline_parameter)
      CommandLine.Error(
        Builtins.sformat(
          # TRANSLATORS: command line error message, %1 is a parameter name
          _("Unknown value for parameter %1."),
          cmdline_parameter
        )
      )

      nil
    end

    # Function for handling commandline 'startup'
    def DNSHandlerStartup(options)
      options = deep_copy(options)
      # both cannot be together
      if Ops.get(options, "atboot") != nil && Ops.get(options, "manual") != nil
        # TRANSLATORS: commandline section header
        ScreenWizard(_("Start-Up Settings:"), "")
        # TRANSLATORS: commandline error message
        CommandLine.Error(_("Only one parameter is allowed.")) 
        # start at boot
      elsif Ops.get(options, "atboot") != nil
        ScreenWizard(
          # TRANSLATORS: commandline section header
          _("Start-Up Settings:"),
          # TRANSLATORS: commandline progress information
          _("Enabling DNS server in the boot process...")
        )
        DnsServer.SetStartService(true)
        return true 
        # start manually
      elsif Ops.get(options, "manual") != nil
        ScreenWizard(
          # TRANSLATORS: commandline section header
          _("Start-Up Settings:"),
          # TRANSLATORS: commandline progress information
          _("Removing DNS server from the boot process...")
        )
        DnsServer.SetStartService(false)
        return true 
        # show current state
      elsif Ops.get(options, "show") != nil
        content = ""
        if DnsServer.GetStartService
          # TRANSLATORS: commandline DNS service status information
          content = _("DNS server is enabled in the boot process.")
        else
          # TRANSLATORS: commandline DNS service status information
          content = _("DNS server needs manual starting.")
        end
        # TRANSLATORS: commandline section header
        ScreenWizard(_("Start-Up Settings:"), content)
        return false
      end

      false
    end

    # Function for handling commandline 'forwarders'
    def DNSHandlerForwarders(options)
      options = deep_copy(options)
      # show current settings
      if Ops.get(options, "show") != nil
        table_items = []
        Builtins.foreach(DnsServerAPI.GetForwarders) do |ip|
          table_items = Builtins.add(table_items, [ip])
        end
        ScreenWizard(
          # TRANSLATORS: commandline section header,
          _("Forwarding:"),
          # TRANSLATORS: commandline table header item
          String.TextTable([_("Forwarder IP")], table_items, {})
        )
        return false
      elsif Ops.get(options, "add") != nil && Ops.get(options, "remove") != nil
        # TRANSLATORS: commandline error message
        CommandLine.Error(_("Only one action parameter is allowed."))
        return false
      elsif Ops.get(options, "add") != nil
        ip = Ops.get_string(options, "ip", "")
        if ip == ""
          Missing("ip")
          return false
        end
        return DnsServerAPI.AddForwarder(ip)
      elsif Ops.get(options, "remove") != nil
        ip = Ops.get_string(options, "ip", "")
        if ip == ""
          Missing("ip")
          return false
        end
        return DnsServerAPI.RemoveForwarder(ip)
      end
      false
    end

    def SetLogTo(settings)
      settings = deep_copy(settings)
      # $[
      #    "type"		: "file",
      #    "file"		: options["file"]:"",
      #    "maxsize"		: options["maxsize"]:"0",
      #    "maxversions"	: options["maxversions"]:"0"
      # ]

      if Ops.get(settings, "type") == "syslog"
        DnsServerAPI.SetLoggingChannel({ "destination" => "syslog" })
      elsif Ops.get(settings, "type") == "file"
        DnsServerAPI.SetLoggingChannel(
          {
            "destination" => "file",
            "filename"    => Ops.get(settings, "file", ""),
            "size"        => Ops.get(settings, "maxsize", ""),
            "versions"    => Ops.get(settings, "maxversions", "")
          }
        )
      else
        # unknown logging
        Builtins.y2error("Unknown logging type '%1'", Ops.get(settings, "type"))
        return
      end

      nil
    end

    # Function returns map $[ queries : (yes|no), updates : (yes|no), transfers : (yes|no) ]
    def GetLoggingAdditionals
      categories = DnsServerAPI.GetLoggingCategories
      addlog = { "queries" => "no", "xfer-in" => "no", "xfer-out" => "no" }

      Builtins.foreach(categories) do |category|
        Ops.set(addlog, category, "yes")
      end

      deep_copy(addlog)
    end

    def DNSHandlerLoggingShow
      table_items = []

      logging_channel = DnsServerAPI.GetLoggingChannel

      if Ops.get(logging_channel, "destination", "syslog") == "syslog"
        table_items = Builtins.add(
          table_items,
          [
            # TRANSLATORS: commandline table item
            _("Logging destination"),
            # TRANSLATORS: commandline table item
            _("System log")
          ]
        )
      elsif Ops.get(logging_channel, "destination", "file") == "file"
        table_items = Builtins.add(
          table_items,
          [
            # TRANSLATORS: commandline table item
            _("Logging destination"),
            # TRANSLATORS: commandline table item
            _("File")
          ]
        )

        table_items = Builtins.add(
          table_items,
          [
            # TRANSLATORS: commandline table item
            _("Filename"),
            Ops.get(logging_channel, "filename", "")
          ]
        )
        table_items = Builtins.add(
          table_items,
          [
            # TRANSLATORS: commandline table item
            _("Maximum size"),
            Ops.get(logging_channel, "size", "")
          ]
        )
        table_items = Builtins.add(
          table_items,
          [
            # TRANSLATORS: commandline table item
            _("Maximum versions"),
            Ops.get(logging_channel, "versions", "")
          ]
        )
      end

      logadds = GetLoggingAdditionals()
      # $[ "queries" : "no", "updates" : "no", "transfers" : "no" ]
      tabadds_items = []
      tabadds_items = Builtins.add(
        tabadds_items,
        [
          # TRANSLATORS: commandline table item, do not translate named
          _("Log named queries"),
          Ops.get(logadds, "queries", "")
        ]
      )
      tabadds_items = Builtins.add(
        tabadds_items,
        [
          # TRANSLATORS: commandline table item
          _("Log zone updates"),
          Ops.get(logadds, "xfer-in", "")
        ]
      )
      tabadds_items = Builtins.add(
        tabadds_items,
        [
          # TRANSLATORS: commandline table item
          _("Log zone transfers"),
          Ops.get(logadds, "xfer-out", "")
        ]
      )

      ScreenWizard(
        # TRANSLATORS: commandline section header
        _("Logging Settings:"),
        Ops.add(
          Ops.add(
            String.TextTable(
              [
                # TRANSLATORS: commandline table header item
                _("Setting"),
                # TRANSLATORS: commandline table header item
                _("Value")
              ],
              table_items,
              {}
            ),
            "\n\n"
          ),
          String.TextTable(
            [
              # TRANSLATORS: commandline table header item
              _("Logging Rule"),
              # TRANSLATORS: commandline table header item
              _("Value")
            ],
            tabadds_items,
            {}
          )
        )
      )

      nil
    end

    # Function for handling logging settings
    def DNSHandlerLogging(options)
      options = deep_copy(options)
      # show current settings
      if Ops.get(options, "show") != nil
        DNSHandlerLoggingShow()
      elsif Ops.get(options, "destination") != nil
        # logging to syslog
        if Ops.get(options, "destination") == "syslog"
          return DnsServerAPI.SetLoggingChannel({ "destination" => "syslog" }) 
          # logging to file
        elsif Ops.get(options, "destination") == "file"
          return DnsServerAPI.SetLoggingChannel(
            {
              "destination" => "file",
              "filename"    => Ops.get_string(options, "file", ""),
              "size"        => Ops.get_string(options, "maxsize", ""),
              "versions"    => Ops.get_string(options, "maxversions", "")
            }
          ) 
          # unknown value
        else
          UnknownValue("destination")
          return false
        end
      elsif Ops.get(options, "set") != nil
        category_mapping = {
          "queries"   => "queries",
          "updates"   => "xfer-in",
          "transfers" => "xfer-out"
        }

        current_categories = DnsServerAPI.GetLoggingCategories
        Builtins.foreach(["queries", "updates", "transfers"]) do |category|
          if Ops.get(options, category) != nil
            enable = Builtins.tolower(Ops.get_string(options, category)) == "yes"
            if enable
              Builtins.y2milestone("Enabling %1", category)
              current_categories = Builtins.toset(
                Builtins.add(
                  current_categories,
                  Ops.get(category_mapping, category, "")
                )
              )
            else
              Builtins.y2milestone("Disabling %1", category)
              current_categories = Builtins.filter(current_categories) do |current|
                Ops.get(category_mapping, category, "") != current
              end
            end
          end
        end
        return DnsServerAPI.SetLoggingCategories(current_categories)
      end
      false
    end

    def DNSHandlerZonesShow
      table_items = []

      Builtins.foreach(DnsServerAPI.GetZones) do |zone_name, zone|
        masterservers = []
        forwarders = []
        if ["slave", "secondary"].include?(zone)
          masterservers = DnsServerAPI.GetZoneMasterServers(zone_name)
        elsif Ops.get(zone, "type") == "forward"
          forwarders = DnsServerAPI.GetZoneForwarders(zone_name)
        end
        table_items = Builtins.add(
          table_items,
          [
            zone_name,
            Ops.get(zone, "type"),
            Builtins.mergestring(masterservers, ", "),
            Builtins.mergestring(forwarders, ", ")
          ]
        )
      end

      ScreenWizard(
        # TRANSLATORS: commandline section header,
        _("DNS Zones:"),
        # TRANSLATORS: commandline table header item
        String.TextTable(
          [
            # TRANSLATORS: commandline table header item
            _("Name"),
            # TRANSLATORS: commandline table header item
            _("Type"),
            # TRANSLATORS: commandline table header item
            _("Master Server"),
            # TRANSLATORS: commandline table header item
            _("Forwarders")
          ],
          table_items,
          {}
        )
      )

      false
    end

    # Function for handling DNS zones in general
    def DNSHandlerZones(options)
      options = deep_copy(options)
      Builtins.y2milestone("Options: %1", options)

      # Show current settings
      primaryserver = options["masterserver"] || options["primaryserver"]
      if Ops.get(options, "show") != nil
        return DNSHandlerZonesShow() 

        # Both Add and Remove defined => Error!
      elsif Ops.get(options, "add") != nil && Ops.get(options, "remove") != nil
        CommandLine.Error(_("Only one action parameter is allowed."))
        return false 

        # Adding zone
      elsif Ops.get(options, "add") != nil
        if DnsServerAPI.AddZone(
            Ops.get_string(options, "name"),
            Ops.get_string(options, "zonetype"),
            { "masterserver" => primaryserver }
          )
          if Ops.get_string(options, "zonetype") == "forward"
            return DnsServerAPI.SetZoneForwarders(
              Ops.get_string(options, "name"),
              Builtins.splitstring(
                Ops.get_string(options, "forwarders", ""),
                ","
              )
            )
          else
            return true
          end
        else
          Builtins.y2error("Cannot add new zone %1", options)
          return false
        end 

        # Removing zone
      elsif Ops.get(options, "remove") != nil
        return DnsServerAPI.RemoveZone(Ops.get_string(options, "name")) 

        # Changing settings
      elsif Ops.get(options, "set") != nil
        # Zone MasterServers
        if primaryserver != nil
          return DnsServerAPI.SetZoneMasterServers(
            Ops.get_string(options, "name"),
            [primaryserver]
          ) 
          # Zone Forwarders
        elsif Ops.get(options, "forwarders") != nil
          return DnsServerAPI.SetZoneForwarders(
            Ops.get_string(options, "name"),
            Builtins.splitstring(Ops.get_string(options, "forwarders", ""), ",")
          )
        end
      end
      false
    end

    def DNSHandlerACLsShow
      table_items = []
      Builtins.foreach(DnsServerAPI.GetACLs) do |name, acl_values|
        table_items = Builtins.add(
          table_items,
          [
            name,
            Ops.get(acl_values, "default", "no") == "yes" ?
              # TRANSLATORS: table item - ACL type
              _("Predefined") :
              # TRANSLATORS: table item - ACL type
              _("Custom"),
            Ops.get(acl_values, "value", "")
          ]
        )
      end

      ScreenWizard(
        # TRANSLATORS: commandline section header
        _("ACLs:"),
        # TRANSLATORS: commandline table header item
        String.TextTable(
          [
            # TRANSLATORS: commandline table header item
            _("Name"),
            # TRANSLATORS: commandline table header item
            _("Type"),
            # TRANSLATORS: commandline table header item
            _("Value")
          ],
          table_items,
          {}
        )
      )

      false
    end

    def DNSHandlerACLs(options)
      options = deep_copy(options)
      if Ops.get(options, "show") != nil
        DNSHandlerACLsShow()
        return false
      end
      false
    end

    def DNSHandlerTransportShow(only_for_zone)
      table_items = []
      Builtins.foreach(DnsServerAPI.GetZones) do |zone_name, zone|
        # skipping all zones which arent requested
        next if only_for_zone != nil && only_for_zone != zone_name
        Builtins.foreach(DnsServerAPI.GetZoneTransportACLs(zone_name)) do |acl|
          table_items = Builtins.add(table_items, [zone_name, acl])
        end
      end

      ScreenWizard(
        # TRANSLATORS: commandline section header
        _("Zone Transport:"),
        # TRANSLATORS: commandline table header item
        String.TextTable(
          [
            # TRANSLATORS: commandline table header item
            _("Zone"),
            # TRANSLATORS: commandline table header item
            _("Enabled ACL")
          ],
          table_items,
          {}
        )
      )

      true
    end

    def DNSHandlerTransport(options)
      options = deep_copy(options)
      if Ops.get(options, "show") != nil
        DNSHandlerTransportShow(Ops.get_string(options, "zone"))
        return false
      elsif Ops.get(options, "enable") != nil &&
          Ops.get(options, "disable") != nil
        CommandLine.Error(_("Only one action parameter is allowed."))
        return false
      elsif Ops.get(options, "enable") != nil
        return DnsServerAPI.AddZoneTransportACL(
          Ops.get_string(options, "zone"),
          Ops.get_string(options, "enable")
        )
      elsif Ops.get(options, "disable") != nil
        return DnsServerAPI.RemoveZoneTransportACL(
          Ops.get_string(options, "zone"),
          Ops.get_string(options, "disable")
        )
      end
      false
    end

    def DNSHandlerNameServersShow(only_for_zone)
      table_items = []
      Builtins.foreach(DnsServerAPI.GetZones) do |zone_name, zone|
        # skipping all zones which arent requested
        next if only_for_zone != nil && only_for_zone != zone_name
        Builtins.foreach(DnsServerAPI.GetZoneNameServers(zone_name)) do |nameserver|
          table_items = Builtins.add(table_items, [zone_name, nameserver])
        end
      end

      ScreenWizard(
        # TRANSLATORS: commandline section header
        _("Name Servers:"),
        # TRANSLATORS: commandline table header item
        String.TextTable(
          [
            # TRANSLATORS: commandline table header item
            _("Zone"),
            # TRANSLATORS: commandline table header item
            _("Name Server")
          ],
          table_items,
          {}
        )
      )
      true
    end

    def DNSHandlerNameServers(options)
      options = deep_copy(options)
      if Ops.get(options, "show") != nil
        DNSHandlerNameServersShow(Ops.get_string(options, "zone"))
        return false
      elsif Ops.get(options, "add") != nil && Ops.get(options, "remove") != nil
        CommandLine.Error(_("Only one action parameter is allowed."))
        return false
      elsif Ops.get(options, "add") != nil
        DnsServerAPI.AddZoneNameServer(
          Ops.get_string(options, "zone"),
          Ops.get_string(options, "ns")
        )
      elsif Ops.get(options, "remove") != nil
        DnsServerAPI.RemoveZoneNameServer(
          Ops.get_string(options, "zone"),
          Ops.get_string(options, "ns")
        )
      end
      false
    end

    def DNSHandlerMailServersShow(only_for_zone)
      table_items = []
      Builtins.foreach(DnsServerAPI.GetZones) do |zone_name, zone|
        # skipping all zones which arent requested
        next if only_for_zone != nil && only_for_zone != zone_name
        Builtins.foreach(DnsServerAPI.GetZoneMailServers(zone_name)) do |mailserver|
          table_items = Builtins.add(
            table_items,
            [
              zone_name,
              Ops.get(mailserver, "name", ""),
              Ops.get(mailserver, "priority", "")
            ]
          )
        end
      end

      ScreenWizard(
        # TRANSLATORS: commandline section header
        _("Mail Servers:"),
        # TRANSLATORS: commandline table header item
        String.TextTable(
          [
            # TRANSLATORS: commandline table header item
            _("Zone"),
            # TRANSLATORS: commandline table header item
            _("Mail Server"),
            # TRANSLATORS: commandline table header item
            _("Priority")
          ],
          table_items,
          {}
        )
      )
      true
    end

    def DNSHandlerMailServers(options)
      options = deep_copy(options)
      if Ops.get(options, "show") != nil
        DNSHandlerMailServersShow(Ops.get_string(options, "zone"))
        return false
      elsif Ops.get(options, "add") != nil && Ops.get(options, "remove") != nil
        CommandLine.Error(_("Only one action parameter is allowed."))
        return false
      elsif Ops.get(options, "add") != nil
        DnsServerAPI.AddZoneMailServer(
          Ops.get_string(options, "zone"),
          Ops.get_string(options, "mx"),
          Ops.get_integer(options, "priority")
        )
      elsif Ops.get(options, "remove") != nil
        if Ops.get(options, "priority") == nil
          Missing("priority")
          return false
        end
        DnsServerAPI.RemoveZoneMailServer(
          Ops.get_string(options, "zone"),
          Ops.get_string(options, "mx"),
          Ops.get_integer(options, "priority")
        )
      end
      false
    end

    def DNSHandlerSOAShow(only_for_zone)
      table_items = []

      if only_for_zone == nil || only_for_zone == ""
        Missing("zone")
        return false
      end

      zone_soa = DnsServerAPI.GetZoneSOA(only_for_zone)
      Builtins.foreach(
        ["serial", "ttl", "refresh", "retry", "expiry", "minimum"]
      ) do |param|
        table_items = Builtins.add(
          table_items,
          [param, Ops.get(zone_soa, param, "")]
        )
      end

      ScreenWizard(
        # TRANSLATORS: commandline section header
        _("Start of Authority (SOA):"),
        # TRANSLATORS: commandline table header item
        String.TextTable(
          [
            # TRANSLATORS: commandline table header item
            _("Key"),
            # TRANSLATORS: commandline table header item
            _("Value")
          ],
          table_items,
          {}
        )
      )
      true
    end

    def DNSHandlerSOA(options)
      options = deep_copy(options)
      if Ops.get(options, "show") != nil
        DNSHandlerSOAShow(Ops.get_string(options, "zone"))
        return false
      elsif Ops.get(options, "set") != nil
        params = {}
        Builtins.foreach(
          ["serial", "ttl", "refresh", "retry", "expiry", "minimum"]
        ) do |param|
          if Ops.get(options, param) != nil && Ops.get(options, param) != ""
            Ops.set(
              params,
              param,
              Builtins.tostring(Ops.get_string(options, param, ""))
            )
          end
        end
        DnsServerAPI.SetZoneSOA(Ops.get_string(options, "zone", ""), params)
      end

      nil
    end

    def DNSHandlerResourceRecordsShow(only_for_zone, only_for_type)
      table_items = []
      Builtins.foreach(DnsServerAPI.GetZones) do |zone_name, zone|
        # skipping all zones which arent requested
        next if only_for_zone != nil && only_for_zone != zone_name
        Builtins.foreach(DnsServerAPI.GetZoneRRs(zone_name)) do |resourcerecord|
          # filtering rr types
          if only_for_type != nil &&
              only_for_type != Ops.get(resourcerecord, "type")
            next
          end
          table_items = Builtins.add(
            table_items,
            [
              zone_name,
              Ops.get(resourcerecord, "key", ""),
              Ops.get(resourcerecord, "type", ""),
              Ops.get(resourcerecord, "value", "")
            ]
          )
        end
      end

      ScreenWizard(
        # TRANSLATORS: commandline section header
        _("Mail Servers:"),
        # TRANSLATORS: commandline table header item
        String.TextTable(
          [
            # TRANSLATORS: commandline table header item
            _("Zone"),
            # TRANSLATORS: commandline table header item
            _("Record Query"),
            # TRANSLATORS: commandline table header item
            _("Record Type"),
            # TRANSLATORS: commandline table header item
            _("Record Value")
          ],
          table_items,
          {}
        )
      )
      true
    end

    def DNSHandlerResourceRecords(options)
      options = deep_copy(options)
      if Ops.get(options, "show") != nil
        DNSHandlerResourceRecordsShow(
          Ops.get_string(options, "zone"),
          Ops.get_string(options, "type")
        )
        return false
      elsif Ops.get(options, "add") != nil && Ops.get(options, "remove") != nil
        CommandLine.Error(_("Only one action parameter is allowed."))
        return false
      elsif Ops.get(options, "add") != nil
        return DnsServerAPI.AddZoneRR(
          Ops.get_string(options, "zone", ""),
          Ops.get_string(options, "type", ""),
          Ops.get_string(options, "query", ""),
          Ops.get_string(options, "value", "")
        )
      elsif Ops.get(options, "remove") != nil
        return DnsServerAPI.RemoveZoneRR(
          Ops.get_string(options, "zone", ""),
          Ops.get_string(options, "type", ""),
          Ops.get_string(options, "query", ""),
          Ops.get_string(options, "value", "")
        )
      end
      false
    end

    def DNSHandlerHostRecordsShow(only_for_zone)
      table_items = []
      Builtins.foreach(DnsServerAPI.GetZoneHosts(only_for_zone)) do |hosts|
        table_items = Builtins.add(
          table_items,
          [
            Ops.get(hosts, "zone", ""),
            Ops.get(hosts, "hostname", ""),
            Ops.get(hosts, "ip", "")
          ]
        )
      end

      ScreenWizard(
        # TRANSLATORS: commandline section header
        _("Hostname Record:"),
        # TRANSLATORS: commandline table header item
        String.TextTable(
          [
            # TRANSLATORS: commandline table header item
            _("Zone"),
            # TRANSLATORS: commandline table header item
            _("Hostname"),
            # TRANSLATORS: commandline table header item
            _("IP")
          ],
          table_items,
          {}
        )
      )
      true
    end

    def DNSHandlerHostRecords(options)
      options = deep_copy(options)
      if Ops.get(options, "show") != nil
        DNSHandlerHostRecordsShow(Ops.get_string(options, "zone"))
        return false
      elsif Ops.get(options, "add") != nil && Ops.get(options, "remove") != nil
        CommandLine.Error(_("Only one action parameter is allowed."))
        return false
      elsif Ops.get(options, "add") != nil
        return DnsServerAPI.AddHost(
          Ops.get_string(options, "zone", ""),
          Ops.get_string(options, "hostname", ""),
          Ops.get_string(options, "ip", "")
        )
      elsif Ops.get(options, "remove") != nil
        return DnsServerAPI.RemoveHost(
          Ops.get_string(options, "zone", ""),
          Ops.get_string(options, "hostname", ""),
          Ops.get_string(options, "ip", "")
        )
      end

      nil
    end
  end
end
