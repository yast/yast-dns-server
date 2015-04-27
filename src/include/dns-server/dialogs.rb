# encoding: utf-8

# File:	modules/DnsServer.ycp
# Package:	Configuration of dns-server
# Summary:	Data for configuration of dns-server, input and output functions.
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
# Representation of the configuration of dns-server.
# Input and output routines.
module Yast
  module DnsServerDialogsInclude
    def initialize_dns_server_dialogs(include_target)
      textdomain "dns-server"

      Yast.import "DnsServer"

      Yast.import "Popup"
      Yast.import "Label"
      Yast.import "CWM"
      Yast.import "Wizard"
      Yast.import "Message"
      Yast.import "SuSEFirewall"
      Yast.import "Punycode"
      Yast.import "Confirm"
    end

    # Ask user if exit without saving
    # @return [Boolean] true if exit
    def ReallyExit
      return true if !DnsServer.WasModified
      # yes-no popup
      Popup.YesNo(_("All changes will be lost.\nReally exit?"))
    end

    # If modified, ask for confirmation
    # @return true if abort is confirmed
    def ReallyAbort
      return true if !DnsServer.WasModified
      Popup.ReallyAbort(true)
    end

    # Ask for confirmation (always)
    # @return true if abort is confirmed
    def ReallyAbortAlways
      Popup.ReallyAbort(true)
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      Wizard.RestoreHelp(Ops.get_string(@HELPS, "read", ""))

      # checking for root permissions
      return :abort if !Confirm.MustBeRoot

      ret = DnsServer.Read
      ret ? :next : :abort
    end

    def runZoneTypeSwitch
      type = Ops.get_string(@current_zone, "type", "master")
      name = Ops.get_string(@current_zone, "zone", "unknown")
      Builtins.y2milestone(
        "Editing zone %1 (%2), type %3",
        name,
        Punycode.DecodeDomainName(name),
        type
      )
      if type == "master"
        return :master
      elsif type == "slave"
        return :slave
      elsif type == "stub"
        return :stub
      elsif type == "forward"
        return :forward
      else
        # message popup
        Popup.Message(_("A zone of this type cannot be edited with this tool."))
        return :back
      end
    end
  end
end
