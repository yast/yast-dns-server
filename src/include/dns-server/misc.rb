# encoding: utf-8

# File:	include/dns-server/misc.ycp
# Package:	Configuration of dns-server
# Summary:	Miscelanous functions for configuration of dns-server.
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
module Yast
  module DnsServerMiscInclude
    def initialize_dns_server_misc(include_target)
      textdomain "dns-server"

      Yast.import "Mode"
      Yast.import "Label"
      Yast.import "Service"
      Yast.import "Wizard"
    end

    def SetDNSSErverIcon
      Wizard.SetDesktopIcon("org.opensuse.yast.DNSServer")

      nil
    end

    # Restart the DNS daemon
    def RestartDnsDaemon
      if Service.Status("named") == 0
        Service.RunInitScript("named", "reload")
      else
        Service.RunInitScript("named", "restart")
      end

      nil
    end

    # Get zone type from the zone identification
    # @param [String] zone string zone identification
    # @return [Symbol] zone type
    def getZoneType(zone)
      if Ops.greater_than(Builtins.size(zone), 12) &&
          Builtins.substring(zone, Ops.subtract(Builtins.size(zone), 12)) == "in-addr.arpa"
        return :reverse
      end
      :normal
    end
  end
end
