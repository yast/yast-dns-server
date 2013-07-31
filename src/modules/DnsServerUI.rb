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
require "yast"

module Yast
  class DnsServerUIClass < Module
    def main
      Yast.import "UI"
      textdomain "dns-server"

      Yast.import "DnsServer"
      Yast.import "DnsTsigKeys"
      Yast.import "DnsZones"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Summary"
      Yast.import "SuSEFirewall"

      Yast.import "DnsFakeTabs" # FIXME remove when possbile

      @current_zone = {}
      @current_section = []
      @current_zone_ns = []
      @current_zone_mx = []
      @current_zone_masters = []
      @current_zone_upd_ops = []

      @current_tsig_keys = []
      @new_tsig_keys = []
      @deleted_tsig_keys = []

      @forwarders = []
      #    string forward = "";

      @options = []
      @current_option_index = 0

      @zones = []

      @acl = []

      @logging = []

      @was_editing_zone = false

      Yast.include self, "dns-server/misc.rb"
      Yast.include self, "dns-server/helps.rb"
      Yast.include self, "dns-server/options.rb"

      # Map of popups for CWM
      @popups = InitPopups()

      Yast.include self, "dns-server/dialogs.rb"
      Yast.include self, "dns-server/dialog-main.rb"
      Yast.include self, "dns-server/dialog-masterzone.rb"
      Yast.include self, "dns-server/dialog-installwizard.rb"
      Yast.include self, "dns-server/wizards.rb" 

      # EOF
    end

    publish :function => :SetDNSSErverIcon, :type => "void ()"
    publish :function => :getZoneType, :type => "symbol (string)"
    publish :variable => :HELPS, :type => "map"
    publish :function => :globalPopupInit, :type => "void (any, string)"
    publish :function => :globalPopupStore, :type => "void (any, string)"
    publish :function => :globalTableEntrySummary, :type => "string (any, string)"
    publish :function => :masterPopupInit, :type => "void (any, string)"
    publish :function => :masterPopupStore, :type => "void (any, string)"
    publish :function => :masterTableEntrySummary, :type => "string (any, string)"
    publish :function => :masterTableLabelFunc, :type => "string (any, string)"
    publish :function => :ASummary, :type => "string (any, string)"
    publish :function => :CNAMESummary, :type => "string (any, string)"
    publish :function => :PTRSummary, :type => "string (any, string)"
    publish :function => :NSSummary, :type => "string (any, string)"
    publish :function => :MXSummary, :type => "string (any, string)"
    publish :function => :MXInit, :type => "void (any, string)"
    publish :function => :MXStore, :type => "void (any, string)"
    publish :function => :InitPopups, :type => "map ()"
    publish :variable => :popups, :type => "map"
    publish :function => :ReallyExit, :type => "boolean ()"
    publish :function => :ReallyAbort, :type => "boolean ()"
    publish :function => :ReallyAbortAlways, :type => "boolean ()"
    publish :function => :ReadDialog, :type => "symbol ()"
    publish :function => :WriteDialog, :type => "symbol ()"
    publish :function => :confirmAbort, :type => "boolean ()"
    publish :function => :confirmAbortIfChanged, :type => "boolean ()"
    publish :variable => :functions, :type => "map <symbol, any>"
    publish :function => :TabSequence, :type => "symbol ()"
    publish :function => :InstallWizardSequence, :type => "symbol ()"
    publish :function => :DnsSequence, :type => "symbol ()"
    publish :function => :DnsAutoSequence, :type => "symbol ()"
  end

  DnsServerUI = DnsServerUIClass.new
  DnsServerUI.main
end
