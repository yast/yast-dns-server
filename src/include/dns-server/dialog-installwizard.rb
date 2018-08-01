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

require "dns-server/service_widget_helpers"

module Yast
  module DnsServerDialogInstallwizardInclude
    include Y2DnsServer::ServiceWidgetHelpers

    def initialize_dns_server_dialog_installwizard(include_target)
      textdomain "dns-server"

      Yast.import "DnsServer"
      Yast.import "IP"
      Yast.import "Popup"
      Yast.import "Label"
      Yast.import "CWM"
      Yast.import "Wizard"
      Yast.import "CWMFirewallInterfaces"
    end

    # Writes settings and save the service
    #
    # @return [Boolean] true if service is saved successfully; false otherwise
    def write_dns_settings
      service_widget.store
      service.save
    end

    def runInstallWizardForwardersDialog
      caption =
        # Dialog caption (before a colon)
        _("DNS Server Installation") + ": " +
          # Dialog caption (after a colon)
          _("Forwarder Settings")

      contents = ExpertForwardersDialog()

      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get_string(@HELPS, "forwarders", ""),
        Label.BackButton,
        Label.NextButton
      )
      SetDNSSErverIcon()
      Wizard.SetAbortButton(:abort, Label.CancelButton)
      Wizard.DisableBackButton
      InitExpertForwardersPage("forwarders")

      event = {}
      ret = nil
      while true
        event = UI.WaitForEvent
        ret = Ops.get(event, "ID")
        if ret == :next
          break
        elsif ret == :cancel || ret == :abort
          if ReallyAbortAlways()
            break
          else
            next
          end
        elsif ret == :back
          break
        else
          HandleExpertForwardersPage("forwarders", event)
        end
      end

      Wizard.RestoreBackButton
      Wizard.RestoreAbortButton
      StoreExpertForwardersPage("forwarders", {}) if ret == :next

      Convert.to_symbol(ret)
    end

    def runInstallWizardZonesDialog
      caption =
        # Dialog caption (before a colon)
        _("DNS Server Installation") + ": " +
          # Dialog caption (after a colon)
          _("DNS Zones")

      Wizard.SetContentsButtons(
        caption,
        ExpertZonesDialog(),
        Ops.get_string(@HELPS, "zones", ""),
        Label.BackButton,
        Label.NextButton
      )
      SetDNSSErverIcon()
      Wizard.RestoreAbortButton
      Wizard.RestoreBackButton
      Wizard.RestoreNextButton
      InitExpertZonesPage("zones")

      event = {}
      ret = nil
      while true
        event = UI.WaitForEvent
        ret = Ops.get(event, "ID")
        if ret == :next
          break
        elsif ret == :cancel || ret == :abort
          if ReallyAbortAlways()
            break
          else
            next
          end
        elsif ret == :back
          break
        elsif ret == "edit_zone"
          index = Convert.to_integer(
            UI.QueryWidget(Id("zones_list_table"), :CurrentItem)
          )
          DnsServer.SelectZone(index)
          @current_zone = DnsServer.FetchCurrentZone
          ret = :edit_zone
          break
        else
          handle_ret = HandleExpertZonesPage("zones", event)
          # fixing bug #45950, slave zone _MUST_ have master server
          # fixing bug #67005, DNS Server Wizard - It's possible to create slave zone without master
          if handle_ret == :edit_zone
            ret = :edit_zone
            break
          end
        end
      end

      StoreExpertZonesPage("zones", {}) if ret == :next || ret == :edit_zone

      Convert.to_symbol(ret)
    end

    def runInstallWizardFinishDialog
      caption =
        # Dialog caption (before a colon)
        _("DNS Server Installation") + ": " +
          # Dialog caption (after a colon)
          _("Finish Wizard")


      ReadForwarders()
      fw = Builtins.mergestring(@forwarders, ", ")
      zones = DnsServer.FetchZones
      zn = Builtins.maplist(zones) { |z| Ops.get_string(z, "zone", "") }
      zl = Builtins.mergestring(zn, ", ")

      rich_text = Ops.add(
        Ops.add(
          Ops.add(
            "<ul>",
            # Rich Text Item - Installation overview
            Builtins.sformat(_("<li>Forwarders: %1</li>"), fw)
          ),
          # Rich Text Item - Installation overview
          Builtins.sformat(_("<li>Domains: %1</li>"), zl)
        ),
        "</ul>"
      )

      firewall_settings = {
        "services"        => ["dns"],
        "display_details" => true
      }
      firewall_widget = CWMFirewallInterfaces.CreateOpenFirewallWidget(
        firewall_settings
      )
      firewall_layout = Ops.get_term(firewall_widget, "custom_widget", VBox())
      firewall_help = Ops.get_string(firewall_widget, "help", "")

      ldap_support = DnsServer.ExpertUI ?
        VBox(
          VSpacing(1),
          # check box
          Left(
            CheckBox(Id("use_ldap"), Opt(:notify), _("&LDAP Support Active"))
          ),
          VSpacing(1)
        ) :
        VSpacing(1)

      dialog = Top(
        VBox(
          # Frame label (DNS starting)
          VBox(
            firewall_layout,
            ldap_support,
            service_widget.contents,
          ),
          RichText(Id("installation_overview"), rich_text),
          VSpacing(2),
          # Push Button - start expert configuration
          PushButton(Id(:expert), _("DNS Server &Expert Configuration...")),
          VStretch()
        )
      )

      Wizard.SetContentsButtons(
        caption,
        dialog,
        Ops.add(
          Ops.get_string(@HELPS, "installwizard_step3", ""),
          firewall_help
        ),
        Label.BackButton,
        Label.NextButton
      )
      SetDNSSErverIcon()
      Wizard.SetNextButton(:next, Label.FinishButton)

      use_ldap = false
      # only expert allows to store data in ldap
      if DnsServer.ExpertUI
        use_ldap = DnsServer.GetUseLdap
        UI.ChangeWidget(Id("use_ldap"), :Value, use_ldap)
      end

      event = {}
      ret = nil
      CWMFirewallInterfaces.OpenFirewallInit(firewall_widget, "")
      while true
        event = UI.WaitForEvent
        ret = Ops.get(event, "ID")
        CWMFirewallInterfaces.OpenFirewallHandle(firewall_widget, "", event)
        if ret == :next
          break
        elsif ret == :expert
          break
        elsif ret == :back
          break
        elsif ret == :cancel || ret == :abort
          if ReallyAbortAlways()
            break
          else
            next
          end
        elsif ret == "use_ldap"
          use_ldap2 = Convert.to_boolean(UI.QueryWidget(Id("use_ldap"), :Value))

          if DnsServer.SetUseLdap(use_ldap2)
            DnsServer.InitYapiConfigOptions({ "use_ldap" => use_ldap2 })
            DnsServer.LdapInit(true, true)
            DnsServer.CleanYapiConfigOptions
          end

          use_ldap2 = DnsServer.GetUseLdap
          UI.ChangeWidget(Id("use_ldap"), :Value, use_ldap2)
        end
      end

      if ret == :next || ret == :expert
        write_dns_settings

        CWMFirewallInterfaces.OpenFirewallStore(firewall_widget, "", event)
      end

      Convert.to_symbol(ret)
    end
  end
end
