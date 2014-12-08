# encoding: utf-8

# File:	clients/dns-server_auto.ycp
# Package:	Configuration of dns-server
# Summary:	Client for autoinstallation
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
# This is a client for autoinstallation. It takes its arguments,
# goes through the configuration and return the setting.
# Does not do any changes to the configuration.

# @param function to execute
# @param map/list of dns-server settings
# @return [Hash] edited settings, Summary or boolean on success depending on called function
# @example map mm = $[ "FAIL_DELAY" : "77" ];
# @example map ret = WFM::CallFunction ("dns-server_auto", [ "Summary", mm ]);
module Yast
  class DnsServerAutoClient < Client
    def main

      textdomain "dns-server"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("DnsServer auto started")

      Yast.import "DnsServer"
      Yast.import "DnsServerUI"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      # Create a summary
      if @func == "Summary"
        @ret = DnsServer.Summary.join("<br>\n")
      # Reset configuration
      elsif @func == "Reset"
        DnsServer.Import({})
        @ret = {}
      # Change configuration (run AutoSequence)
      elsif @func == "Change"
        @ret = DnsServerUI.DnsAutoSequence
      # Import configuration
      elsif @func == "Import"
        @ret = DnsServer.Import(@param)
      # Return actual state
      elsif @func == "Export"
        @ret = DnsServer.Export
      # Return needed packages
      elsif @func == "Packages"
        @ret = DnsServer.AutoPackages
      elsif @func == "GetModified"
        @ret = DnsServer.WasModified
      elsif @func == "SetModified"
        DnsServer.SetModified
        @ret = true
      # Read current state
      elsif @func == "Read"
        Yast.import "Progress"
        @progress_orig = Progress.set(false)
        @ret = DnsServer.Read
        Progress.set(@progress_orig)
      # Write givven settings
      elsif @func == "Write"
        Yast.import "Progress"
        @progress_orig = Progress.set(false)
        DnsServer.SetWriteOnly(true)
        @ret = DnsServer.Write
        Progress.set(@progress_orig)
      else
        Builtins.y2error("Unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("DnsServer auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end
  end
end

Yast::DnsServerAutoClient.new.main
