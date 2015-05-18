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
  module DnsServerWizardsInclude
    def initialize_dns_server_wizards(include_target)
      textdomain "dns-server"

      Yast.import "Directory"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Sequencer"
      Yast.import "Wizard"
    end

    def TabSequence
      aliases = {
        "main"             => lambda { runExpertDialog },
        "zone_type_switch" => [lambda { runZoneTypeSwitch }, true],
        "master_zone_tab"  => lambda { runMasterZoneTabDialog },
        "slave_zone_tab"   => lambda { runSlaveZoneTabDialog },
        "stub_zone_tab"    => lambda { runStubZoneTabDialog },
        "forward_zone_tab" => lambda { runForwardZoneTabDialog }
      }

      sequence = {
        "ws_start"         => "main",
        "main"             => {
          :abort     => :abort,
          :next      => :next,
          :edit_zone => "zone_type_switch"
        },
        "zone_type_switch" => {
          :abort   => :abort,
          :master  => "master_zone_tab",
          :slave   => "slave_zone_tab",
          :stub    => "stub_zone_tab",
          :forward => "forward_zone_tab"
        },
        "master_zone_tab"  => { :abort => :abort, :next => "main" },
        "slave_zone_tab"   => { :abort => :abort, :next => "main" },
        "stub_zone_tab"    => { :abort => :abort, :next => "main" },
        "forward_zone_tab" => { :abort => :abort, :next => "main" }
      }

      # Do not let DnsServer manage the service status, let the user decide
      DnsServer.SetWriteOnly(true)
      ret = Sequencer.Run(aliases, sequence)

      ret
    end

    def InstallWizardSequence
      aliases = {
        "forwarders"       => lambda { runInstallWizardForwardersDialog },
        "zones"            => lambda { runInstallWizardZonesDialog },
        "finish"           => lambda { runInstallWizardFinishDialog },
        "tab_seq"          => lambda { TabSequence() },
        "zone_type_switch" => [lambda { runZoneTypeSwitch }, true],
        "master_zone_tab"  => lambda { runMasterZoneTabDialog },
        "slave_zone_tab"   => lambda { runSlaveZoneTabDialog },
        "stub_zone_tab"    => lambda { runStubZoneTabDialog },
        "forward_zone_tab" => lambda { runForwardZoneTabDialog }
      }

      sequence = {
        "ws_start"         => "forwarders",
        "forwarders"       => { :next => "zones", :abort => :abort },
        "zones"            => {
          :next      => "finish",
          :abort     => :abort,
          :edit_zone => "zone_type_switch"
        },
        "finish"           => {
          :next   => :next,
          :abort  => :abort,
          :expert => "tab_seq"
        },
        "tab_seq"          => { :abort => :abort, :next => :next },
        "zone_type_switch" => {
          :abort   => :abort,
          :master  => "master_zone_tab",
          :slave   => "slave_zone_tab",
          :stub    => "stub_zone_tab",
          :forward => "forward_zone_tab"
        },
        "master_zone_tab"  => { :abort => :abort, :next => "zones" },
        "slave_zone_tab"   => { :abort => :abort, :next => "zones" },
        "stub_zone_tab"    => { :abort => :abort, :next => "zones" },
        "forward_zone_tab" => { :abort => :abort, :next => "zones" }
      }

      # In wizard mode, the current status and the status at boot are synced
      DnsServer.SetWriteOnly(false)
      ret = Sequencer.Run(aliases, sequence)

      ret
    end

    # Whole configuration of dns-server
    # @return sequence result
    def DnsSequence
      aliases = {
        "read"   => [lambda { ReadDialog() }, true],
        "main"   => lambda { TabSequence() },
        "wizard" => lambda { InstallWizardSequence() },
        "write"  => [lambda { WriteDialog() }, true]
      }

      sequence = {
        "ws_start" => "read",
        "read"     => { :abort => :abort, :next => "main" },
        "main"     => { :abort => :abort, :next => "write" },
        "wizard"   => { :abort => :abort, :next => "write" },
        "write"    => { :abort => :abort, :next => :next }
      }

      Wizard.CreateDialog
      SetDNSSErverIcon()

      sequence["read"][:next] = "wizard" if DnsServer.first_run

      ret = Sequencer.Run(aliases, sequence)

      UI.CloseDialog
      ret
    end

    # Whole configuration of dns-server
    # @return sequence result
    def DnsAutoSequence
      aliases = { "main" => lambda { TabSequence() } }

      sequence = {
        "ws_start" => "main",
        "main"     => { :abort => :abort, :next => :next }
      }

      Wizard.CreateDialog
      SetDNSSErverIcon()

      ret = Sequencer.Run(aliases, sequence)

      UI.CloseDialog
      ret
    end
  end
end
