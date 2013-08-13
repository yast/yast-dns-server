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
  module DnsServerDialogMasterzoneInclude
    MAX_TEXT_RECORD_LENGTH = 255

    module SOADefaults
      DNS_SERVER = '.'
      EMAIL_ADDRESS = 'root.'
      SERIAL = '1111111111'
      REFRESH = '3h'
      RETRY = '1h'
      EXPIRY = '1w'
      MINIMUM = '1d'
    end

    def initialize_dns_server_dialog_masterzone(include_target)
      textdomain "dns-server"

      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "DnsServer"
      Yast.import "DnsFakeTabs"
      Yast.import "DnsRoutines"
      Yast.import "DnsServerAPI"
      Yast.import "Confirm"
      Yast.import "Hostname"
      Yast.import "IP"
      Yast.import "Popup"
      Yast.import "DnsTsigKeys"
      Yast.import "Mode"
      Yast.import "Report"
      Yast.import "Punycode"
      Yast.import "DnsServerHelperFunctions"

      Yast.include include_target, "dns-server/misc.rb"

      @available_zones_to_connect = []

      @supported_records    = []
      @supported_records_ui = []

      @last_add_record_type = nil

      # current RR type used in `ReplacePoint (`id ("rr_rp"))
      @current_rr_rp = nil

      # All current forwarders are stored here
      @current_zone_forwarders = []
    end

    # Dialog Tab - Zone Editor - Basics
    # @return [Yast::Term] for Get_ZoneEditorTab()
    def GetMasterZoneEditorTabBasics
      updater_keys_m = DnsTsigKeys.ListTSIGKeys
      updater_keys = Builtins.maplist(updater_keys_m) do |m|
        Ops.get_string(m, "key", "")
      end
      acl = DnsServer.GetAcl
      acl = Builtins.maplist(acl) do |a|
        while Builtins.substring(a, 0, 1) == " " ||
            Builtins.substring(a, 0, 1) == "\t"
          a = Builtins.substring(a, 1)
        end
        s = Builtins.splitstring(a, " \t")
        type = Ops.get(s, 0, "")
        type
      end
      acl = Builtins.filter(acl) { |a| a != "" }
      acl = Convert.convert(
        Builtins.sort(
          Builtins.merge(acl, ["any", "none", "localhost", "localnets"])
        ),
        :from => "list",
        :to   => "list <string>"
      )

      expert_settings = Empty()
      if DnsServer.ExpertUI
        expert_settings = VBox(
          Left(
            CheckBoxFrame(
              Id("allow_ddns"),
              Opt(:notify),
              # check box
              _("A&llow Dynamic Updates"),
              true,
              Left(
                ReplacePoint(
                  Id(:ddns_key_rp),
                  # combo box
                  HSquash(
                    ComboBox(
                      Id("ddns_key"),
                      Opt(:hstretch),
                      _("TSIG &Key"),
                      updater_keys
                    )
                  )
                )
              )
            )
          ),
          VSpacing(1)
        )
      end

      # bug #203910
      # hide "none" from listed ACLs
      # "none" means, not allowed and thus multiselectbox of ACLs is disabled
      acl = Builtins.filter(acl) { |one_acl| one_acl != "none" }

      @available_zones_to_connect = []
      zone_name = ""
      zones_to_connect = Builtins.maplist(@zones) do |z|
        zone_name = Ops.get_string(z, "zone", "")
        # zone must be: reverse, not-internal, master
        if DnsServerHelperFunctions.IsReverseZone(zone_name) ||
            DnsServerHelperFunctions.IsInternalZone(zone_name) ||
            Ops.get_string(z, "type", "") != "master"
          next nil
        end
        @available_zones_to_connect = Builtins.add(
          @available_zones_to_connect,
          zone_name
        )
        Item(Id(zone_name), Punycode.DecodeDomainName(zone_name))
      end
      zones_to_connect = Builtins.sort(Builtins.filter(zones_to_connect) do |one_zone|
        one_zone != nil
      end)

      zones_connected = DnsServer.GetWhichZonesAreConnectedWith(
        Ops.get_string(@current_zone, "zone", "")
      )
      Builtins.y2milestone(
        "Connected with zone %1: %2",
        Ops.get_string(@current_zone, "zone", ""),
        zones_connected
      )

      contents = VBox(
        expert_settings,
        Left(
          CheckBoxFrame(
            Id("enable_zone_transport"),
            Opt(:notify),
            # check box
            _("Enable &Zone Transport"),
            true,
            # multi selection box
            VSquash(
              HSquash(
                MinWidth(30, MultiSelectionBox(Id("acls_list"), _("ACLs"), acl))
              )
            )
          )
        ),
        VSpacing(1),
        # Reverse zones can be automatically generated
        DnsServerHelperFunctions.IsReverseZone(
          Ops.get_string(@current_zone, "zone", "")
        ) == true ?
          Left(
            CheckBoxFrame(
              Id("generate_from_forward_zone"),
              Opt(:notify),
              # check box
              _("A&utomatically Generate Records From"),
              true,
              # multi selection box
              VSquash(
                HSquash(
                  MinWidth(
                    30,
                    ComboBox(
                      Id("generate_from_forward_zone_sel"),
                      _("Zon&e"),
                      zones_to_connect
                    )
                  )
                )
              )
            )
          ) :
          Ops.greater_than(Builtins.size(zones_connected), 0) ?
            Left(
              Frame(
                # frame label
                _("Connected Reverse Zones"),
                VBox(Label(Builtins.mergestring(zones_connected, "\n")))
              )
            ) :
            Empty(),
        VStretch()
      )

      deep_copy(contents)
    end

    def ZoneAclInit
      allowed = false
      keys = []
      Builtins.foreach(Ops.get_list(@current_zone, "options", [])) do |m|
        if Ops.get_string(m, "key", "") == "allow-transfer" && !allowed
          key = Builtins.regexpsub(
            Ops.get_string(m, "value", ""),
            "^.*\\{[ \t]*(.*)[ \t]*\\}.*$",
            "\\1"
          )
          if key != nil
            keys = Builtins.splitstring(key, " ;")
            keys = Builtins.filter(keys) { |k| k != "" }
            allowed = true
          end
        end
      end

      # bug #203910
      # no keys in allow-transfer means that transfer is allowed for all
      # explicitly say that
      if Builtins.size(keys) == 0
        allowed = true
        keys = ["any"] 
        # the only way how to disable the transfer is to set "allow-transfer { none; };"
        # "none" must be alone, remove it from the list, it is not present in the multi-sel box
      elsif Builtins.size(keys) == 1 && keys == ["none"]
        allowed = false
        keys = []
      end

      UI.ChangeWidget(Id("enable_zone_transport"), :Value, allowed)
      UI.ChangeWidget(Id("acls_list"), :Enabled, allowed)
      UI.ChangeWidget(Id("acls_list"), :SelectedItems, keys) if allowed

      nil
    end

    def ZoneConnectedWithInit
      if DnsServerHelperFunctions.IsReverseZone(
          Ops.get_string(@current_zone, "zone", "")
        ) == true
        if Ops.get_string(@current_zone, "connected_with", "") != "" &&
            Builtins.contains(
              @available_zones_to_connect,
              Ops.get_string(@current_zone, "connected_with", "")
            )
          UI.ChangeWidget(
            Id("generate_from_forward_zone_sel"),
            :Value,
            Ops.get_string(@current_zone, "connected_with", "")
          )
          UI.ChangeWidget(Id("generate_from_forward_zone"), :Value, true)
        else
          UI.ChangeWidget(Id("generate_from_forward_zone"), :Value, false)
        end
      end

      nil
    end

    def ZoneAclStore
      Ops.set(
        @current_zone,
        "options",
        Builtins.maplist(Ops.get_list(@current_zone, "options", [])) do |m|
          if Ops.get_string(m, "key", "") == "allow-transfer" &&
              Builtins.regexpmatch(
                Ops.get_string(m, "value", ""),
                "^.*\\{[ \t]*(.*)[ \t]*\\}.*$"
              )
            next {}
          end
          deep_copy(m)
        end
      )
      Ops.set(
        @current_zone,
        "options",
        Builtins.filter(Ops.get_list(@current_zone, "options", [])) do |m|
          m != {}
        end
      )
      keys = Convert.convert(
        UI.QueryWidget(Id("acls_list"), :SelectedItems),
        :from => "any",
        :to   => "list <string>"
      )
      allowed = Convert.to_boolean(
        UI.QueryWidget(Id("enable_zone_transport"), :Value)
      )


      # bug #203910
      # always store the allow-transfer option explicitly
      # if zone transfer is not allowed, set allow-transfer to { none; };
      if !allowed
        keys = ["none"]
        Builtins.y2milestone("ZoneTransfer not allowed, keys: %1", keys) 
        # otherwise set selected keys
      else
        Builtins.y2milestone("Zone transfer is allowed, keys: %1", keys)
        # no ACL selected means "any" is selected by default
        keys = ["any"] if Builtins.size(keys) == 0
      end

      # store either "none" (transfer disabled) or "all" (transfer enabled)
      # or selected ACLs (transfer enabled for selected ACLs)
      Ops.set(
        @current_zone,
        "options",
        Builtins.add(
          Ops.get_list(@current_zone, "options", []),
          {
            "key"   => "allow-transfer",
            "value" => Builtins.sformat(
              "{ %1; }",
              Builtins.mergestring(keys, "; ")
            )
          }
        )
      )

      nil
    end

    def ZoneConnectedWithStore
      if DnsServerHelperFunctions.IsReverseZone(
          Ops.get_string(@current_zone, "zone", "")
        )
        if Convert.to_boolean(
            UI.QueryWidget(Id("generate_from_forward_zone"), :Value)
          ) == true
          Ops.set(
            @current_zone,
            "connected_with",
            Convert.to_string(
              UI.QueryWidget(Id("generate_from_forward_zone_sel"), :Value)
            )
          )
        else
          Ops.set(@current_zone, "connected_with", "")
        end

        Builtins.y2milestone(
          "Zone '%1' connected with '%2'",
          Ops.get_string(@current_zone, "zone", ""),
          Ops.get_string(@current_zone, "connected_with", "")
        )
      end

      nil
    end

    def ZoneAclHandle(event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")
      UI.ChangeWidget(
        Id("acls_list"),
        :Enabled,
        Convert.to_boolean(UI.QueryWidget(Id("enable_zone_transport"), :Value))
      )

      nil
    end

    # <-- zone ACL

    # --> zone Basic

    # Initialize the tab of the dialog
    def InitZoneBasicsTab
      SetDNSSErverIcon()

      allowed = false
      key = nil
      Builtins.foreach(Ops.get_list(@current_zone, "options", [])) do |m|
        if Ops.get_string(m, "key", "") == "allow-update" && !allowed
          key = Builtins.regexpsub(
            Ops.get_string(m, "value", ""),
            "^.*key[ \t]+([^ \t;]+)[ \t;]+.*$",
            "\\1"
          )
          allowed = true if key != nil
        end
      end
      if DnsServer.ExpertUI
        UI.ChangeWidget(Id("allow_ddns"), :Value, allowed)
        UI.ChangeWidget(Id("ddns_key"), :Enabled, allowed)

        UI.ChangeWidget(Id("ddns_key"), :Value, key) if allowed
      end

      ZoneAclInit()
      ZoneConnectedWithInit()

      nil
    end

    # Store settings of a tab of a dialog
    def StoreZoneBasicsTab
      Ops.set(
        @current_zone,
        "options",
        Builtins.maplist(Ops.get_list(@current_zone, "options", [])) do |m|
          if Ops.get_string(m, "key", "") == "allow-update" &&
              Builtins.regexpmatch(
                Ops.get_string(m, "value", ""),
                "^.*key[ \t]+[^ \t;]+[ \t;]+.*$"
              )
            next {}
          end
          deep_copy(m)
        end
      )
      Ops.set(
        @current_zone,
        "options",
        Builtins.filter(Ops.get_list(@current_zone, "options", [])) do |m|
          m != {}
        end
      )

      if DnsServer.ExpertUI
        key = Convert.to_string(UI.QueryWidget(Id("ddns_key"), :Value))
        allowed = Convert.to_boolean(UI.QueryWidget(Id("allow_ddns"), :Value))
        if allowed
          Ops.set(
            @current_zone,
            "options",
            Builtins.add(
              Ops.get_list(@current_zone, "options", []),
              {
                "key"   => "allow-update",
                "value" => Builtins.sformat("{ key %1; }", key)
              }
            )
          )
        end
      end
      ZoneAclStore()
      ZoneConnectedWithStore()

      nil
    end

    # Handle events in a tab of a dialog
    def HandleZoneBasicsTab(event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")

      if DnsServer.ExpertUI
        if ret == "allow_ddns" && Mode.config
          # popup message
          Popup.Message(
            _(
              "This function is not available during\npreparation for autoinstallation.\n"
            )
          )
          UI.ChangeWidget(Id("allow_ddns"), :Value, false)
          return nil
        end
        if ret == "allow_ddns" &&
            Convert.to_boolean(UI.QueryWidget(Id("allow_ddns"), :Value)) &&
            Builtins.size(DnsTsigKeys.ListTSIGKeys) == 0
          # error report
          Report.Error(_("No TSIG key is defined."))
          UI.ChangeWidget(Id("allow_ddns"), :Value, false)
        end
        UI.ChangeWidget(
          Id("ddns_key"),
          :Enabled,
          Convert.to_boolean(UI.QueryWidget(Id("allow_ddns"), :Value))
        )
      end

      ZoneAclHandle(event)
      nil
    end

    # <-- zone Basic

    # --> zone NS

    # Dialog Tab - Zone Editor - Name Servers
    # @return [Yast::Term] for Get_ZoneEditorTab()
    def GetMasterZoneEditorTabNameServers
      contents = VBox(
        VSquash(
          HBox(
            HWeight(
              7,
              # Textentry - adding nameserver
              InputField(
                Id("add_name_server"),
                Opt(:hstretch),
                _("&Name Server to Add")
              )
            ),
            HWeight(
              2,
              VBox(
                VStretch(),
                VSquash(
                  PushButton(Id("add_ns"), Opt(:hstretch), Label.AddButton)
                )
              )
            )
          )
        ),
        HBox(
          HWeight(
            7,
            ReplacePoint(
              Id("name_server_list_rp"),
              # Selectionbox - listing current nameservers
              SelectionBox(
                Id("name_server_list"),
                Opt(:hstretch),
                _("Na&me Server List"),
                []
              )
            )
          ),
          HWeight(
            2,
            VBox(
              VSquash(VSpacing(1)),
              VSquash(
                PushButton(Id("delete_ns"), Opt(:hstretch), Label.DeleteButton)
              ),
              VStretch()
            )
          )
        )
      )
      deep_copy(contents)
    end

    def RedrawNsListWidget
      UI.ReplaceWidget(
        Id("name_server_list_rp"),
        SelectionBox(
          Id("name_server_list"),
          # selection box label
          _("Na&me Server List"),
          Punycode.DocodeDomainNames(@current_zone_ns)
        )
      )

      nil
    end

    #/**
    # * Setting ValidChars for dialog
    # */
    #void ValidCharsNsListWidget () {
    #    UI::ChangeWidget( `id ("add_name_server"), `ValidChars, Hostname::ValidCharsFQ);
    #}

    def RegenerateCurrentZoneNS
      zone_name = Ops.get_string(@current_zone, "zone", "")
      records = Builtins.filter(Ops.get_list(@current_zone, "records", [])) do |r|
        Ops.get_string(r, "type", "") == "NS" &&
          (Ops.get_string(r, "key", "") == Builtins.sformat("%1.", zone_name) ||
            Ops.get_string(r, "key", "") == "@")
      end
      @current_zone_ns = Builtins.maplist(records) do |r|
        Ops.get_string(r, "value", "")
      end
      @current_zone_ns = Builtins.filter(@current_zone_ns) { |z| z != "" }
      Builtins.y2milestone("NSs: %1", @current_zone_ns)

      nil
    end

    # Initialize the tab of the dialog
    def InitNsListTab
      RegenerateCurrentZoneNS()
      RedrawNsListWidget() 
      #ValidCharsNsListWidget ();

      nil
    end

    # Store settings of a tab of a dialog
    def StoreNsListTab
      zone_name = Ops.get_string(@current_zone, "zone", "")
      records = Builtins.filter(Ops.get_list(@current_zone, "records", [])) do |r|
        !(Ops.get_string(r, "type", "") == "NS" &&
          (Ops.get_string(r, "key", "") == Builtins.sformat("%1.", zone_name) ||
            Ops.get_string(r, "key", "") == zone_name ||
            Ops.get_string(r, "key", "") == "@"))
      end
      new_rec = Builtins.maplist(@current_zone_ns) do |a|
        {
          "key"   => Builtins.sformat("%1.", zone_name),
          "type"  => "NS",
          "value" => a
        }
      end
      Ops.set(@current_zone, "records", Builtins.merge(new_rec, records))

      nil
    end

    # Handle events in a tab of a dialog
    def HandleNsListTab(event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")

      if ret == "add_ns"
        zn = Ops.add(Ops.get_string(@current_zone, "zone", ""), ".")

        # NS is converted to the Punycode first
        new_ns_entered = Convert.to_string(
          UI.QueryWidget(Id("add_name_server"), :Value)
        )
        new_ns = Punycode.EncodeDomainName(new_ns_entered)
        Builtins.y2milestone("New NS: %1", new_ns)

        check_ns = new_ns
        if Builtins.regexpmatch(check_ns, "^.*\\.$")
          check_ns = Builtins.regexpsub(check_ns, "^(.*)\\.$", "\\1")
        end

        # validating name server
        if Hostname.Check(check_ns) != true &&
            Hostname.CheckFQ(check_ns) != true
          UI.SetFocus(Id("add_name_server"))
          # A popup error message
          Popup.Error(Hostname.ValidDomain)
          return nil
        end
        # absolute hostname
        if Builtins.regexpmatch(new_ns, "\\..*[^.]$")
          new_ns = Ops.add(new_ns, ".")
        elsif Builtins.regexpmatch(new_ns, "^[^.]*$")
          new_ns = Builtins.sformat("%1.%2", new_ns, zn)
        end
        if Builtins.contains(@current_zone_ns, new_ns)
          UI.SetFocus(Id("add_name_server"))
          # error message
          Popup.Error(_("The specified name server already exists."))
          return nil
        end

        current_zone_ref = arg_ref(@current_zone)
        DnsServerHelperFunctions.HandleNsupdate(
          { "type" => "NS", "key" => zn, "value" => new_ns },
          "add",
          current_zone_ref
        )
        @current_zone = current_zone_ref.value

        @current_zone_ns = Builtins.add(@current_zone_ns, new_ns)
        RedrawNsListWidget()
      elsif ret == "delete_ns"
        selected = Convert.to_string(
          UI.QueryWidget(Id("name_server_list"), :CurrentItem)
        )
        @current_zone_ns = Builtins.filter(@current_zone_ns) do |ns|
          ns != selected
        end
        RedrawNsListWidget()

        zn = Ops.add(Ops.get_string(@current_zone, "zone", ""), ".")
        current_zone_ref = arg_ref(@current_zone)
        DnsServerHelperFunctions.HandleNsupdate(
          { "type" => "NS", "key" => zn, "value" => selected },
          "delete",
          current_zone_ref
        )
        @current_zone = current_zone_ref.value
      end
      nil
    end

    # <-- zone NS

    # --> zone MX

    # Dialog Tab - Zone Editor - Mail Servers
    # @return [Yast::Term] for Get_ZoneEditorTab()
    def GetMasterZoneEditorTabMailServers
      contents = VBox(
        VSquash(
          Frame(
            # Frame label - adding mail server
            _("Mail Server to Add"),
            VBox(
              HBox(
                HWeight(
                  7,
                  HBox(
                    # Textentry - addind mail server - Name
                    InputField(
                      Id("add_mail_server"),
                      Opt(:hstretch),
                      _("&Address")
                    ),
                    # IntField - adding mail server - Priority
                    IntField(Id("add_priority"), _("&Priority"), 0, 65535, 0)
                  )
                ),
                HWeight(
                  2,
                  VBox(
                    VStretch(),
                    VSquash(
                      PushButton(Id("add_mx"), Opt(:hstretch), Label.AddButton)
                    )
                  )
                )
              ),
              VSpacing(0.5)
            )
          )
        ),
        HBox(
          HWeight(
            7,
            VBox(
              # Table label - listing mail servers
              Left(Label(_("Mail Relay List"))),
              Table(
                Id("mail_server_list"),
                Header(
                  # Table header item - listing mail servers
                  _("Mail Server"),
                  # Table header item - listing mail servers
                  _("Priority")
                ),
                []
              )
            )
          ),
          HWeight(
            2,
            VBox(
              VSquash(VSpacing(1)),
              VSquash(
                PushButton(Id("delete_mx"), Opt(:hstretch), Label.DeleteButton)
              ),
              VStretch()
            )
          )
        )
      )
      deep_copy(contents)
    end

    def RedrawMxListWidget
      zone_mx_decoded = Punycode.DocodeDomainNames(@current_zone_mx)

      index = -1
      # create term items using already translated strings
      items = Builtins.maplist(zone_mx_decoded) do |one_mx|
        one_address_name = one_mx
        one_address_name = Builtins.regexpsub(
          one_address_name,
          "^[0123456789]+[ \t]+(.*)$",
          "\\1"
        )
        one_priority = one_mx
        one_priority = Builtins.regexpsub(
          one_priority,
          "^([0123456789]+)[ \t]+.*$",
          "\\1"
        )
        index = Ops.add(index, 1)
        Item(Id(index), one_address_name, one_priority)
      end

      items = Builtins.sort(items) do |x, y|
        Ops.less_than(Ops.get_string(x, 1, ""), Ops.get_string(y, 2, ""))
      end

      # initialize the widget content
      UI.ChangeWidget(Id("mail_server_list"), :Items, items)

      nil
    end

    #/**
    # * Setting ValidChars for dialog
    # */
    #void ValidCharsMxListTab () {
    #    UI::ChangeWidget( `id ("add_mail_server"), `ValidChars, Hostname::ValidCharsFQ);
    #}

    # Initialize the tab of the dialog
    def InitMxListTab
      zone_name = Ops.get_string(@current_zone, "zone", "")
      records = Builtins.filter(Ops.get_list(@current_zone, "records", [])) do |r|
        Ops.get_string(r, "type", "") == "MX" &&
          (Ops.get_string(r, "key", "") == Builtins.sformat("%1.", zone_name) ||
            Ops.get_string(r, "key", "") == "@")
      end
      @current_zone_mx = Builtins.maplist(records) do |r|
        Ops.get_string(r, "value", "")
      end
      @current_zone_mx = Builtins.filter(@current_zone_mx) { |z| z != "" }

      RedrawMxListWidget()

      nil
    end

    # Store settings of a tab of a dialog
    def StoreMxListTab
      zone_name = Ops.get_string(@current_zone, "zone", "")
      records = Builtins.filter(Ops.get_list(@current_zone, "records", [])) do |r|
        !(Ops.get_string(r, "type", "") == "MX" &&
          (Ops.get_string(r, "key", "") == Builtins.sformat("%1.", zone_name) ||
            Ops.get_string(r, "key", "") == zone_name ||
            Ops.get_string(r, "key", "") == "@"))
      end
      new_rec = Builtins.maplist(@current_zone_mx) do |a|
        {
          "key"   => Builtins.sformat("%1.", zone_name),
          "type"  => "MX",
          "value" => a
        }
      end
      Ops.set(@current_zone, "records", Builtins.merge(new_rec, records))

      nil
    end

    # Handle events in a tab of a dialog
    def HandleMxListTab(event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")

      if ret == "add_mx"
        new_mx_decoded = Convert.to_string(
          UI.QueryWidget(Id("add_mail_server"), :Value)
        )
        new_mx = Punycode.EncodeDomainName(new_mx_decoded)

        prio = Convert.to_integer(UI.QueryWidget(Id("add_priority"), :Value))
        # maximal priority is 65535
        if Ops.greater_than(prio, 65535)
          prio = 65535
          UI.ChangeWidget(Id("add_priority"), :Value, 65535)
        end

        zn = Ops.add(Ops.get_string(@current_zone, "zone", ""), ".")

        check_mx = new_mx
        if Builtins.regexpmatch(check_mx, "^.*\\.$")
          check_mx = Builtins.regexpsub(check_mx, "^(.*)\\.$", "\\1")
        end

        # validating mail server
        if Hostname.Check(check_mx) != true &&
            Hostname.CheckFQ(check_mx) != true
          UI.SetFocus(Id("add_mail_server"))
          # A popup error message
          Popup.Error(
            _("The specified value is not a valid hostname or IP address.")
          )
          return nil
        end

        # absolute hostname
        if Builtins.regexpmatch(new_mx, "\\..*[^.]$")
          new_mx = Ops.add(new_mx, ".")
        # relative hostname
        elsif Builtins.regexpmatch(new_mx, "^[^.]*$")
          new_mx = Builtins.sformat("%1.%2", new_mx, zn)
        end

        mx_list_check = Builtins.filter(@current_zone_mx) do |mx|
          split = Builtins.splitstring(mx, " \t")
          split = Builtins.filter(split) { |s| s != "" }
          address = Ops.get(split, 1, "")
          address == new_mx
        end
        if Ops.greater_than(Builtins.size(mx_list_check), 0)
          UI.SetFocus(Id("add_name_server"))
          # error message
          Popup.Error(_("The specified mail server already exists."))
          return nil
        end

        new_mx = Builtins.sformat("%1 %2", prio, new_mx)
        Builtins.y2milestone("New MX: %1", new_mx)

        current_zone_ref = arg_ref(@current_zone)
        DnsServerHelperFunctions.HandleNsupdate(
          { "type" => "MX", "key" => zn, "value" => new_mx },
          "add",
          current_zone_ref
        )
        @current_zone = current_zone_ref.value

        @current_zone_mx = Builtins.add(@current_zone_mx, new_mx)
        RedrawMxListWidget()
      elsif ret == "delete_mx"
        selected = Convert.to_integer(
          UI.QueryWidget(Id("mail_server_list"), :CurrentItem)
        )
        selected_value = Ops.get(@current_zone_mx, selected, "")
        Ops.set(@current_zone_mx, selected, nil)
        @current_zone_mx = Builtins.filter(@current_zone_mx) { |mx| mx != nil }
        RedrawMxListWidget()

        zn = Ops.add(Ops.get_string(@current_zone, "zone", ""), ".")
        current_zone_ref = arg_ref(@current_zone)
        DnsServerHelperFunctions.HandleNsupdate(
          { "type" => "MX", "key" => zn, "value" => selected_value },
          "delete",
          current_zone_ref
        )
        @current_zone = current_zone_ref.value
      end
      nil
    end

    # <-- zone MX

    # --> zone SOA

    # Dialog Tab - Zone Editor - Zone Settings
    # @return [Yast::Term] for Get_ZoneEditorTab()
    def GetMasterZoneEditorTabSOASettings
      dns_units = [
        # DNS Settings time units (combobox item)
        Item(Id(""), _("Seconds")),
        # DNS Settings time units (combobox item)
        Item(Id("m"), _("Minutes")),
        # DNS Settings time units (combobox item)
        Item(Id("h"), _("Hours")),
        # DNS Settings time units (combobox item)
        Item(Id("d"), _("Days")),
        # DNS Settings time units (combobox item)
        Item(Id("w"), _("Weeks"))
      ]

      contents = VBox(
        HBox(
          HWeight(
            50,
            VBox(
              # Textentry - setting Serial for zone
              InputField(
                Id("zone_settings_serial"),
                Opt(:hstretch),
                _("Seri&al"),
                ""
              ),
              VSpacing(1),
              HBox(
                # Textentry - setting TTL for zone
                IntField(
                  Id("zone_settings_ttl_value"),
                  Opt(:hstretch),
                  _("TT&L"),
                  0,
                  9999999,
                  0
                ),
                ComboBox(Id("zone_settings_ttl_units"), _("&Unit"), dns_units)
              ),
              VStretch()
            )
          ),
          HSpacing(2),
          HWeight(
            50,
            VBox(
              HBox(
                Opt(:hstretch),
                # IntField - Setting DNS Refresh - Value
                IntField(
                  Id("zone_settings_refresh_value"),
                  _("Re&fresh"),
                  0,
                  9999999,
                  0
                ),
                # Combobox - Setting DNS Refresh - Unit
                ComboBox(
                  Id("zone_settings_refresh_units"),
                  _("Un&it"),
                  dns_units
                )
              ),
              HBox(
                Opt(:hstretch),
                # IntField - Setting DNS Retry - Value
                IntField(
                  Id("zone_settings_retry_value"),
                  _("Retr&y"),
                  0,
                  9999999,
                  0
                ),
                # Combobox - Setting DNS Retry - Unit
                ComboBox(Id("zone_settings_retry_units"), _("&Unit"), dns_units)
              ),
              HBox(
                Opt(:hstretch),
                # IntField - Setting DNS Expiry - Value
                IntField(
                  Id("zone_settings_expiry_value"),
                  _("Ex&piration"),
                  0,
                  9999999,
                  0
                ),
                # Combobox - Setting DNS Expiry - Unit
                ComboBox(
                  Id("zone_settings_expiry_units"),
                  _("U&nit"),
                  dns_units
                )
              ),
              HBox(
                Opt(:hstretch),
                # IntField - Setting DNS Minimum - Value
                IntField(
                  Id("zone_settings_minimum_value"),
                  _("&Minimum"),
                  0,
                  9999999,
                  0
                ),
                # Combobox - Setting DNS Minimum - Unit
                ComboBox(
                  Id("zone_settings_minimum_units"),
                  _("Uni&t"),
                  dns_units
                )
              ),
              VStretch()
            )
          )
        )
      )
      deep_copy(contents)
    end

    def num2unit(num)
      unit = Builtins.filterchars(Builtins.tolower(num), "smhdw")
      return "" if Builtins.size(unit) == 0
      unit = Builtins.substring(unit, 0, 1)
      unit = "" if unit == "s"
      unit
    end

    # Initialize the tab of the dialog
    def InitSoaTab
      UI.ChangeWidget(
        Id("zone_settings_serial"),
        :Value,
        Ops.get_string(@current_zone, ["soa", "serial"], "")
      )

      map_ids_to_values = {
        "zone_settings_ttl"     => "ttl",
        "zone_settings_refresh" => "refresh",
        "zone_settings_retry"   => "retry",
        "zone_settings_expiry"  => "expiry",
        "zone_settings_minimum" => "minimum"
      }

      Builtins.foreach(map_ids_to_values) do |id, value|
        time_int = 0
        if id == "zone_settings_ttl"
          time_int = DnsServerAPI.TimeToSeconds(
            Ops.get_string(@current_zone, value, "0S")
          )
        else
          time_int = DnsServerAPI.TimeToSeconds(
            Ops.get_string(@current_zone, ["soa", value], "0S")
          )
        end
        time_str = DnsServerAPI.SecondsToHighestTimeUnit(time_int)
        UI.ChangeWidget(
          Id(Ops.add(id, "_value")),
          :Value,
          Builtins.tointeger(Builtins.filterchars(time_str, "0123456789"))
        )
        UI.ChangeWidget(
          Id(Ops.add(id, "_units")),
          :Value,
          Builtins.tolower(Builtins.filterchars(time_str, "WwDdHhMmSs"))
        )
      end

      UI.ChangeWidget(Id("zone_settings_serial"), :ValidChars, "0123456789")

      nil
    end

    # Store SOA dialog settings
    def StoreSoaTab
      @current_zone['ttl'] = "%{ttl_value}%{ttl_units}" % {
        :ttl_value => UI.QueryWidget(Id('zone_settings_ttl_value'), :Value),
        :ttl_units => UI.QueryWidget(Id('zone_settings_ttl_units'), :Value)
      }

      soa_update = {
        'serial' => UI.QueryWidget(Id('zone_settings_serial'), :Value),
        'refresh' => "%{refresh_value}%{refresh_units}" % {
          :refresh_value => UI.QueryWidget(Id('zone_settings_refresh_value'), :Value),
          :refresh_units => UI.QueryWidget(Id('zone_settings_refresh_units'), :Value)
        },
        'retry' => "%{retry_value}%{retry_units}" % {
          :retry_value => UI.QueryWidget(Id('zone_settings_retry_value'), :Value),
          :retry_units => UI.QueryWidget(Id('zone_settings_retry_units'), :Value)
        },
        'expiry' => "%{expiry_value}%{expiry_units}" % {
          :expiry_value => UI.QueryWidget(Id('zone_settings_expiry_value'), :Value),
          :expiry_units => UI.QueryWidget(Id('zone_settings_expiry_units'), :Value)
        },
        'minimum' => "%{minimum_value}%{minimum_units}" % {
          :minimum_value => UI.QueryWidget(Id('zone_settings_minimum_value'), :Value),
          :minimum_units => UI.QueryWidget(Id('zone_settings_minimum_units'), :Value)
        }
      }

      @current_zone['soa'] = {} unless @current_zone.has_key?('soa')
      @current_zone['soa'].merge!(soa_update)

      @current_zone['update_actions'] = [] unless @current_zone.has_key?('update_actions')
      @current_zone['update_actions'] << {
        'operation' => 'add',
        'type'      => 'SOA',
        'key'       => @current_zone['zone'] + '.',
        'value'     => "%{server} %{mail} %{serial} %{refresh} %{retry} %{expiry} %{minimum}" % {
                         :server  => @current_zone['soa'].fetch('server',  SOADefaults::DNS_SERVER),
                         :mail    => @current_zone['soa'].fetch('mail',    SOADefaults::EMAIL_ADDRESS),
                         :serial  => @current_zone['soa'].fetch('serial',  SOADefaults::SERIAL),
                         :refresh => @current_zone['soa'].fetch('refresh', SOADefaults::REFRESH),
                         :retry   => @current_zone['soa'].fetch('retry',   SOADefaults::RETRY),
                         :expiry  => @current_zone['soa'].fetch('expiry',  SOADefaults::EXPIRY),
                         :minimum => @current_zone['soa'].fetch('minimum', SOADefaults::MINIMUM)
                       }
      }
    end

    # Handle events in a tab of a dialog
    def HandleSoaTab(event)
      nil
    end

    def ValidateSoaTab(event)
      serial = Convert.to_string(
        UI.QueryWidget(Id("zone_settings_serial"), :Value)
      )
      if serial == ""
        UI.SetFocus(Id("zone_settings_serial"))
        Popup.Error(_("The serial number of the zone must be specified."))
        return false
      end
      if Ops.greater_than(Builtins.size(serial), 10)
        UI.SetFocus(Id("zone_settings_serial"))
        Popup.Error(
          Builtins.sformat(
            # error report, %1 is an integer
            _("The serial number must be no more than %1 digits long."),
            10
          )
        )
        return false
      end
      refresh_str = Builtins.sformat(
        "%1%2",
        UI.QueryWidget(Id("zone_settings_refresh_value"), :Value),
        UI.QueryWidget(Id("zone_settings_refresh_units"), :Value)
      )
      expiry_str = Builtins.sformat(
        "%1%2",
        UI.QueryWidget(Id("zone_settings_expiry_value"), :Value),
        UI.QueryWidget(Id("zone_settings_expiry_units"), :Value)
      )
      refresh = Builtins.tointeger(DnsRoutines.NormalizeTime(refresh_str))
      expiry = Builtins.tointeger(DnsRoutines.NormalizeTime(expiry_str))
      if Ops.less_than(expiry, refresh)
        # TRANSLATORS: A popup with question, current setting could produce errors
        if !Popup.YesNo(
            _(
              "The expiration time-out is higher than the time period\n" +
                "of zone refreshes. The zone will not be reachable\n" +
                "from slave name servers all the time.\n" +
                "Continue?"
            )
          )
          return false
        end
      end
      true
    end

    def GetEditationWidgets(rec_type)
      ret = nil

      case rec_type
        when "MX"
          ret = HBox(
            # Textentry - zone settings - Record Name
            Top(
              InputField(
                Id("add_record_name"),
                Opt(:hstretch),
                _("&Record Key")
              )
            ),
            # Combobox - zone settings - Record Type
            Top(
              ComboBox(
                Id("add_record_type"),
                Opt(:notify),
                _("T&ype"),
                @supported_records_ui
              )
            ),
            # IntField - zone settings - Record Value
            Top(
              HSquash(
                IntField(
                  Id("add_record_prio"),
                  Opt(:hstretch),
                  _("&Priority"),
                  0,
                  65535,
                  0
                )
              )
            ),
            # Textentry - zone settings - Record Value
            Top(InputField(Id("add_record_val"), Opt(:hstretch), _("Val&ue")))
          )
        when "SRV"
          ret = HBox(
            VBox(
              # Textentry - zone settings - Record Name
              InputField(
                Id("add_record_name"),
                Opt(:hstretch),
                _("&Record Key")
              ),
              HBox(
                # Textentry - zone settings - Record Name
                ComboBox(
                  Id("add_record_service"),
                  Opt(:editable, :hstretch),
                  _("&Service"),
                  [
                    Item("_http"),
                    Item("_ftp"),
                    Item("_imap"),
                    Item("_ldap"),
                    Item("_PK"),
                    Item("_XREP")
                  ]
                ),
                # Textentry - zone settings - Record Name
                ComboBox(
                  Id("add_record_protocol"),
                  Opt(:editable, :hstretch),
                  _("&Protocol"),
                  [Item("_tcp"), Item("_udp")]
                ),
                HStretch()
              )
            ),
            Top(
              # Combobox - zone settings - Record Type
              ComboBox(
                Id("add_record_type"),
                Opt(:notify),
                _("T&ype"),
                @supported_records_ui
              )
            ),
            VBox(
              # IntField - zone settings - Record Value
              InputField(Id("add_record_val"), Opt(:hstretch), _("Val&ue")),
              HBox(
                # IntField - zone settings - Record Value
                IntField(Id("add_record_prio"), _("&Priority"), 0, 65535, 0),
                # IntField - zone settings - Record Value
                IntField(Id("add_record_weight"), _("&Weight"), 0, 65535, 0),
                # IntField - zone settings - Record Value
                IntField(Id("add_record_port"), _("&Port"), 0, 65535, 0)
              )
            )
          )
        # "A", "AAAA", "CNAME", "NS", "PTR", "TXT", "SPF"
        else
          ret = HBox(
            # Textentry - zone settings - Record Name
            Top(
              InputField(
                Id("add_record_name"),
                Opt(:hstretch),
                _("&Record Key")
              )
            ),
            # Combobox - zone settings - Record Type
            Top(
              ComboBox(
                Id("add_record_type"),
                Opt(:notify),
                _("T&ype"),
                @supported_records_ui
              )
            ),
            # Textentry - zone settings - Record Value
            Top(InputField(Id("add_record_val"), Opt(:hstretch), _("Val&ue")))
          )
      end

      deep_copy(ret)
    end

    # Dialog Tab - Zone Editor - Records
    # @return [Yast::Term] for Get_ZoneEditorTab()
    def GetMasterZoneEditorTabRecords
      # reverse zone
      if DnsServerHelperFunctions.IsReverseZone(
          Ops.get_string(@current_zone, "zone", "")
        )
        @supported_records = ["PTR", "NS"]
      else
        @supported_records = ["A", "AAAA", "CNAME", "NS", "MX", "SRV", "TXT", "SPF"]
      end

      record_type_descriptions = {
        "A"     => _("A: IPv4 Domain Name Translation"),
        "AAAA"  => _("AAAA: IPv6 Domain Name Translation"),
        "CNAME" => _("CNAME: Alias for Domain Name"),
        "NS"    => _("NS: Name Server"),
        "MX"    => _("MX: Mail Relay"),
        "PTR"   => _("PTR: Reverse Translation"),
        "SRV"   => _("SRV: Services Record"),
        "TXT"   => _("TXT: Text Record"),
        "SPF"   => _("SPF: Sender Policy Framework"),
      }

      @supported_records_ui = Builtins.maplist(@supported_records) do |one_rec_type|
        Item(
          Id(one_rec_type),
          Ops.get(record_type_descriptions, one_rec_type, one_rec_type)
        )
      end

      @current_rr_rp = GetEditationWidgets(nil)

      contents = VBox(
        HStretch(),
        VSquash(
          # Frame label - Adding/Changing IP/CNAME/Type... zone settings
          Frame(
            _("Record Settings"),
            VBox(
              HBox(
                HWeight(
                  11,
                  # Will be replaced with another box of widgets
                  # after selecting another RR type
                  ReplacePoint(Id("rr_rp"), @current_rr_rp)
                ),
                HWeight(
                  2,
                  VBox(
                    VSpacing(2),
                    # Pushbutton - Change Record
                    VSquash(
                      PushButton(
                        Id("change_record"),
                        Opt(:hstretch),
                        _("C&hange")
                      )
                    ),
                    VSquash(
                      PushButton(
                        Id("add_record"),
                        Opt(:hstretch),
                        Label.AddButton
                      )
                    )
                  )
                )
              )
            )
          )
        ),
        VSpacing(0.5),
        # Table label - Records listing
        Left(Label(_("Configured Resource Records"))),
        HBox(
          HWeight(
            11,
            VBox(
              Table(
                Id("records_list"),
                Opt(:notify, :immediate),
                Header(
                  # Table menu item - Records listing
                  _("Record Key"),
                  # Table menu item - Records listing
                  _("Type"),
                  # Table menu item - Records listing
                  _("Value")
                ),
                []
              )
            )
          ),
          HWeight(
            2,
            VBox(
              VSquash(
                PushButton(
                  Id("delete_record"),
                  Opt(:hstretch),
                  Label.DeleteButton
                )
              ),
              VStretch()
            )
          )
        )
      )
      deep_copy(contents)
    end

    def AdjustEditationWidgets(current_record, decoded_zone_name, zone_name)
      current_record = deep_copy(current_record)
      current_type = Ops.get_string(current_record, "type", "A")

      current_key = Ops.get_string(current_record, "key", "")
      current_val = Ops.get_string(current_record, "value", "")

      current_service = ""
      current_protocol = ""

      current_prio = 0
      current_weight = 0
      current_port = 0

      case current_type
        when "SRV"
          if Builtins.regexpmatch(current_key, "^_[^_]+\\._[^_]+\\.?")
            current_service = Builtins.regexpsub(
              current_key,
              "^(_[^_]+)\\._[^_]+\\.?.*",
              "\\1"
            )
            current_protocol = Builtins.regexpsub(
              current_key,
              "^_[^_]+\\.(_[^\\.]+)\\.?.*",
              "\\1"
            )
            current_key = Builtins.regexpsub(
              current_key,
              "^_[^_]+\\._[^\\.]+\\.?(.*)$",
              "\\1"
            )

            # not to show an empty string
            current_key = Ops.add(zone_name.value, ".") if current_key == ""
          elsif current_key != "" && Builtins.regexpmatch(current_key, "[ \\t]")
            Builtins.y2error("Invalid record key: %1", current_key)
          end

          UI.ChangeWidget(Id("add_record_service"), :Value, current_service)
          UI.ChangeWidget(Id("add_record_protocol"), :Value, current_protocol)

          if Builtins.regexpmatch(
              current_val,
              "^[0-9]+[ \\t]+[0-9]+[ \\t]+[0-9]+.*"
            )
            current_prio = Builtins.tointeger(
              Builtins.regexpsub(
                current_val,
                "^([0-9]+)[ \\t]+[0-9]+[ \\t]+[0-9]+.*$",
                "\\1"
              )
            )
            current_weight = Builtins.tointeger(
              Builtins.regexpsub(
                current_val,
                "^[0-9]+[ \\t]+([0-9]+)[ \\t]+[0-9]+.*$",
                "\\1"
              )
            )
            current_port = Builtins.tointeger(
              Builtins.regexpsub(
                current_val,
                "^[0-9]+[ \\t]+[0-9]+[ \\t]+([0-9]+).*$",
                "\\1"
              )
            )
            current_val = Builtins.regexpsub(
              current_val,
              "^[0-9]+[ \\t]+[0-9]+[ \\t]+[0-9]+[ \\t]+(.*)$",
              "\\1"
            )
          elsif current_val != "" && Builtins.regexpmatch(current_val, "[ \\t]")
            Builtins.y2error("Invalid record val: %1", current_val)
          end

          UI.ChangeWidget(Id("add_record_prio"), :Value, current_prio)
          UI.ChangeWidget(Id("add_record_weight"), :Value, current_weight)
          UI.ChangeWidget(Id("add_record_port"), :Value, current_port)
        when "MX"
          if Builtins.regexpmatch(current_val, "[0-9]+[ \\t]+.*")
            current_prio = Builtins.tointeger(
              Builtins.regexpsub(current_val, "([0-9]+)[ \\t]+.*", "\\1")
            )
            current_val = Builtins.regexpsub(
              current_val,
              "[0-9]+[ \\t]+(.*)",
              "\\1"
            )
          elsif current_val != "" && Builtins.regexpmatch(current_val, "[ \\t]")
            Builtins.y2error("Invalid record val: %1", current_val)
          end

          UI.ChangeWidget(Id("add_record_prio"), :Value, current_prio)
        # "A", "AAAA", "CNAME", "NS", "PTR", "TXT", "SPF"
        else

      end

      # Applies to all
      UI.ChangeWidget(
        Id("add_record_name"),
        :Value,
        DnsServerHelperFunctions.RRToRelativeName(
          Punycode.DecodeDomainName(current_key),
          decoded_zone_name.value,
          current_type,
          "key"
        )
      )
      UI.ChangeWidget(Id("add_record_type"), :Value, current_type)
      UI.ChangeWidget(
        Id("add_record_val"),
        :Value,
        DnsServerHelperFunctions.RRToRelativeName(
          Punycode.DecodeDomainName(current_val),
          decoded_zone_name.value,
          current_type,
          "value"
        )
      )

      nil
    end

    def RedrawZonesTable
      index = -1
      zone_name = Ops.get_string(@current_zone, "zone", "")
      decoded_zone_name = Punycode.DecodeDomainName(zone_name)

      ret = Builtins.maplist(Ops.get_list(@current_zone, "records", [])) do |m|
        index = Ops.add(index, 1)
        if Ops.get_string(m, "type", "") == "TTL" ||
            Ops.get_string(m, "type", "") == "ORIGIN"
          next -1
        end
        if (Ops.get_string(m, "type", "") == "NS" ||
            Ops.get_string(m, "type", "") == "MX") &&
            (Ops.get_string(m, "key", "") == Builtins.sformat("%1.", zone_name) ||
              Ops.get_string(m, "key", "") == "@")
          next -1
        end
        next -1 if Ops.get_string(m, "type", "") == "comment"
        index
      end
      ret = Builtins.filter(ret) { |r2| r2 != nil && r2 != -1 }

      # keys
      decoded_names = Builtins.maplist(ret) do |r2|
        Ops.get_string(@current_zone, ["records", r2, "key"], "")
      end

      const_plus = Builtins.size(decoded_names)

      # values
      Builtins.foreach(Builtins.maplist(ret) do |r2|
        Ops.get_string(@current_zone, ["records", r2, "value"], "")
      end) { |record| decoded_names = Builtins.add(decoded_names, record) }
      decoded_names = Punycode.DecodePunycodes(decoded_names)

      counter = -1
      items = Builtins.maplist(ret) do |r2|
        counter = Ops.add(counter, 1)
        record_type = Ops.get_string(@current_zone, ["records", r2, "type"], "")
        Item(
          Id(r2),
          DnsServerHelperFunctions.RRToRelativeName(
            Ops.get(
              decoded_names,
              counter,
              Ops.get_string(@current_zone, ["records", r2, "key"], "")
            ),
            decoded_zone_name,
            record_type,
            "key"
          ),
          record_type,
          DnsServerHelperFunctions.RRToRelativeName(
            Ops.get(
              decoded_names,
              Ops.add(counter, const_plus),
              Ops.get_string(@current_zone, ["records", r2, "value"], "")
            ),
            decoded_zone_name,
            record_type,
            "value"
          )
        )
      end

      # remember the last selected item
      r = Convert.to_integer(UI.QueryWidget(Id("records_list"), :CurrentItem))
      r = Ops.get_integer(items, [0, 0, 0], 0) if r == nil

      # Redraw
      UI.ChangeWidget(Id("records_list"), :Items, items)

      # Set CurrentItem again
      if Ops.greater_than(Builtins.size(items), 0)
        UI.ChangeWidget(Id("records_list"), :CurrentItem, r)
      end

      UI.ChangeWidget(
        Id("delete_record"),
        :Enabled,
        Ops.greater_than(Builtins.size(items), 0)
      )
      UI.ChangeWidget(
        Id("change_record"),
        :Enabled,
        Ops.greater_than(Builtins.size(items), 0)
      )

      if Ops.greater_than(Builtins.size(items), 0)
        r = Convert.to_integer(UI.QueryWidget(Id("records_list"), :CurrentItem))

        current_record = Ops.get_map(@current_zone, ["records", r], {})
        current_type = Ops.get_string(current_record, "type", "A")

        current_type_ref = arg_ref(current_type)
        decoded_zone_name_ref = arg_ref(decoded_zone_name)
        zone_name_ref = arg_ref(zone_name)
        SwitchAndAdjustEditationWidgets(
          current_type_ref,
          current_record,
          decoded_zone_name_ref,
          zone_name_ref
        )
        current_type = current_type_ref.value
        decoded_zone_name = decoded_zone_name_ref.value
        zone_name = zone_name_ref.value
      end

      nil
    end

    #/**
    # * Setting ValidChars for dialog
    # */
    # void ValidCharsZoneRecordsTab () {
    #    UI::ChangeWidget( `id ("add_record_name"),	`ValidChars,	Hostname::ValidCharsFQ);
    #    UI::ChangeWidget( `id ("add_record_val"),	`ValidChars,	Hostname::ValidCharsFQ + " ");
    #}

    # Initialize the tab of the dialog
    def InitZoneRecordsTab
      RedrawZonesTable()

      nil
    end

    # Store settings of a tab of a dialog
    def StoreZoneRecordsTab
      nil
    end

    # Checks whether a given string is a valid TXT record key (name)
    def ValidTextRecordName(name)
      # Checking the length
      if name == nil || name == ""
        Builtins.y2warning("TXT record key must not be empty")
        return false
      end

      # Checking for forbidden '='
      if Builtins.regexpmatch(name, "=")
        Builtins.y2warning(
          "TXT record key %1 must not contain a '=' character.",
          name
        )
        return false
      end

      # only US-ASCII characters are allowed
      if Builtins.size(name) != Builtins.size(Builtins.toascii(name))
        Builtins.y2warning(
          "TXT record key %1 contains some non US-ASCII characters",
          name
        )
        return false
      end

      true
    end

    # Checking new record by the "type"
    def CheckNewZoneRecordSyntax(record)
      record = deep_copy(record)
      # $[ "key" : key, "type" : type, "val" : val ]

      type = Ops.get(record, "type", "")
      key = Ops.get(record, "key", "")
      val = Ops.get(record, "val", "")

      if Builtins.regexpmatch(key, "^.*\\.$")
        key = Builtins.regexpsub(key, "^(.*)\\.$", "\\1")
      end
      if Builtins.regexpmatch(val, "^.*\\.$")
        val = Builtins.regexpsub(val, "^(.*)\\.$", "\\1")
      end

      # -- A -- \\
      if type == "A"
        # (hostname or FQ -> IPv4)
        # BNC #646895: Wildcard '*' not supported as valid hostname
        if Hostname.Check(key) != true && Hostname.CheckFQ(key) != true &&
            key != "*"
          UI.SetFocus(Id("add_record_name"))
          Popup.Error(Hostname.ValidFQ)
          return false
        end
        if IP.Check4(val) != true
          UI.SetFocus(Id("add_record_val"))
          Popup.Error(IP.Valid4)
          return false
        end
        return true 

        # -- CNAME -- \\
      elsif type == "CNAME"
        # (hostname or FQ -> hostname or FQ)
        if Hostname.Check(key) != true && Hostname.CheckFQ(key) != true &&
            key != "*"
          UI.SetFocus(Id("add_record_name"))
          Popup.Error(Hostname.ValidFQ)
          return false
        end
        if Hostname.Check(val) != true && Hostname.CheckFQ(val) != true
          UI.SetFocus(Id("add_record_val"))
          Popup.Error(Hostname.ValidFQ)
          return false
        end
        return true 

        # -- NS -- \\
      elsif type == "NS"
        # (hostname or domain or FQ -> hostname or FQ)
        if Hostname.Check(key) != true && Hostname.CheckDomain(key) != true &&
            Hostname.CheckFQ(key) != true &&
            key != "*"
          UI.SetFocus(Id("add_record_name"))
          Popup.Error(Hostname.ValidFQ)
          return false
        end
        if Hostname.Check(val) != true && Hostname.CheckFQ(val) != true
          UI.SetFocus(Id("add_record_val"))
          Popup.Error(Hostname.ValidFQ)
          return false
        end
        return true 

        # -- MX -- \\
      elsif type == "MX"
        if Builtins.regexpmatch(val, "^[ \t]*[0-9]+[ \t]+[^ \t].*$")
          val = Builtins.regexpsub(val, "^[ \t]*[0-9]+[ \t]+([^ \t].*)$", "\\1") 
          # FIXME: check also priority
        end
        # (hostname or domain or FQ -> hostname or FQ)
        if Hostname.Check(key) != true && Hostname.CheckDomain(key) != true &&
            Hostname.CheckFQ(key) != true &&
            key != "*"
          UI.SetFocus(Id("add_record_name"))
          Popup.Error(Hostname.ValidFQ)
          return false
        end
        if Hostname.Check(val) != true && Hostname.CheckFQ(val) != true
          UI.SetFocus(Id("add_record_val"))
          Popup.Error(Hostname.ValidFQ)
          return false
        end
        return true 

        # -- PTR -- \\
      elsif type == "PTR"
        val = Ops.get(record, "val", "")

        # (hostname or domain or FQ)
        if Hostname.CheckFQ(val) != true || !Builtins.regexpmatch(val, "\\.*$")
          UI.SetFocus(Id("add_record_val"))
          Popup.Error(Hostname.ValidFQ)
          return false
        end

        zone_name = Ops.add(Ops.get_string(@current_zone, "zone", ""), ".")

        # IPv6 reverse zone
        if Builtins.regexpmatch(zone_name, ".*\\.ip6\\.arpa\\.?$")
          key = Ops.get(record, "key", "")

          # relative reverse IPv6
          if !Builtins.regexpmatch(key, "\\.[ \\t]*$")
            key = Ops.add(Ops.add(key, "."), zone_name)
          end
          if !Builtins.regexpmatch(
              key,
              "^[ \\t]*([0-9a-fA-F]\\.){32}ip6\\.arpa\\.[ \\t]*$"
            )
            Builtins.y2error("Wrong reverse IPv6: '%1'", key)
            UI.SetFocus(Id("add_record_name"))
            # Pop-up error message, %1 is replaced with an example
            Popup.Error(
              Builtins.sformat(
                _(
                  "Invalid IPv6 reverse IP.\n" +
                    "\n" +
                    "IPv6 reverse records are supported either in the full form (%1)\n" +
                    "or in the relative form to the current zone."
                ),
                "*.ip6.arpa."
              )
            )
            return false
          end 
          # IPv4 reverse zone
        else
          num = "(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])"
          ipv4_incompl = Ops.add(
            Ops.add(Ops.add(Ops.add(Ops.add("^", num), "(\\."), num), "){0,3}"),
            "(\\.in-addr\\.arpa)*\\.*$"
          )
          if !Builtins.regexpmatch(key, ipv4_incompl)
            UI.SetFocus(Id("add_record_name"))
            Popup.Error(Hostname.ValidFQ)
            return false
          end
        end

        return true 

        # -- AAAA -- \\
      elsif type == "AAAA"
        # (hostname or FQ)
        if Hostname.Check(key) != true && Hostname.CheckFQ(key) != true &&
            key != "*"
          UI.SetFocus(Id("add_record_name"))
          Popup.Error(Hostname.ValidFQ)
          return false
        end
        if IP.Check6(val) != true
          UI.SetFocus(Id("add_record_val"))
          Popup.Error(_("Invalid IPv6 address."))
          return false
        end
        return true 

        # -- SRV -- \\
      elsif type == "SRV"
        # int int int hostname
        if Builtins.regexpmatch(
            val,
            "^[ \t]*[0-9]+[ \t]+[0-9]+[ \t]+[0-9]+[ \t]+[^ \t].*$"
          )
          val = Builtins.regexpsub(
            val,
            "^[ \t]*[0-9]+[ \t]+[0-9]+[ \t]+[0-9]+[ \t]+([^ \t].*)$",
            "\\1"
          ) 
          # FIXME: check also other values (ints)
        end
        if Hostname.Check(val) != true && Hostname.CheckFQ(val) != true
          UI.SetFocus(Id("add_record_val"))
          Popup.Error(Hostname.ValidFQ)
          return false
        end
        return true 

      # TXT or SPF
      elsif type == "TXT" or type == "SPF"
        if !ValidTextRecordName(key)
          UI.SetFocus(Id("add_record_name"))
          # TRANSLATORS: Error message
          # %{type} replaced with record type (TXT or SPF)
          Popup.Error(
            _(
              "Invalid %{type} record key. It should consist of printable US-ASCII characters excluding '='\nand must be at least one character long."
            ) % {:type => type}
          )
          return false
        end
        if val.size > MAX_TEXT_RECORD_LENGTH
          UI.SetFocus(Id("add_record_val"))
          # TRANSLATORS: Error message
          # %{type}    - replaced with record type (TXT or SPF)
          # %{max}     - replaced with the maximal length
          # %{current} - replaced with the current length of a new TXT record.
          Popup.Error(
            _(
                "Maximal length of a %{type} record is %{max} characters.\nThis message is %{current} characters long."
            ) % {:type => type, :max => MAX_TEXT_RECORD_LENGTH, :current => val.size}
          )
          return false
        end
        return true
      end

      Builtins.y2error("unknown record type: %1", Ops.get(record, "type", ""))
      false
    end

    # Checking new record by the "type"
    def CheckNewZoneRecordLogic(record)

      type = record['type']
      key  = record['key']
      val  = record['val']

      case type
        when "CNAME"
          # (hostname or FQ -> hostname or FQ)
          if key == val
            UI.SetFocus(Id("add_record_val"))
            # TRANSLATORS: a popup message, CNAME (link) points to itself
            Popup.Error(_("CNAME cannot point to itself."))
            return false
          end
          return true
        when *@supported_records
          # FIXME: A record should point to an IPv4 address
          # FIXME: AAAA record should point to IPv6 address
          # FIXME: NS should point to an A or AAAA record (if it is in the same domain)
          # FIXME: MX should point to an A or AAAA record (if it is in the same domain)
          # FIXME: SRV should point to an A or AAAA record (if it is in the same domain)
          return true
        else
          Builtins.y2error("unknown record type: #{type}")
          return false
      end
    end

    # Transform a given key/value by adding the ending dot if
    # it ends with the current zone name
    def TransformRecord(record)
      zone_regexp = Builtins.mergestring(
        Builtins.splitstring(Ops.get_string(@current_zone, "zone", ""), "."),
        "\\."
      )

      # key terminated with zone name without dot
      if Builtins.regexpmatch(
          record,
          Ops.add(Ops.add(".*\\.", zone_regexp), "$")
        )
        record = Ops.add(record, ".")
      end

      record
    end

    def CheckAndModifyRecord(type, key, val)
      # (SYNTAX) Checking the record by record-type (true or false)
      if CheckNewZoneRecordSyntax(
          { "key" => key.value, "type" => type.value, "val" => val.value }
        ) != true
        return false
      end
      # (LOGIC) Checking the record by record-type (true or false)
      if CheckNewZoneRecordLogic(
          { "key" => key.value, "type" => type.value, "val" => val.value }
        ) != true
        return false
      end

      tolower_type = Builtins.tolower(type.value)

      if tolower_type == nil || tolower_type == ""
        Builtins.y2error("tolover(%1) -> %2", type.value, tolower_type)
        return false
      end

      if tolower_type == "ptr"
        # no dot at the end
        if !Builtins.regexpmatch(val.value, "^.*\\.$")
          # add dot
          val.value = Ops.add(val.value, ".")
        end

        if Builtins.regexpmatch(key.value, "in-addr\\.arpa$") ||
            Builtins.regexpmatch(key.value, "ip6\\.arpa$")
          key.value = Ops.add(key.value, ".")
        end
      elsif Builtins.contains(["a", "cname", "ns", "mx"], tolower_type)
        if tolower_type == "mx"
          if !Builtins.regexpmatch(val.value, "^[ \t]*[0-9]+[ \t]+[^ \t].*$")
            val.value = Ops.add("0 ", val.value)
          else
            prio = Builtins.tointeger(
              Builtins.regexpsub(
                val.value,
                "^[ \t]*([0-9]+)[ \t]+[^ \t].*$",
                "\\1"
              )
            )
            if Ops.greater_than(prio, 65535)
              val.value = Ops.add(
                "65535 ",
                Builtins.regexpsub(
                  val.value,
                  "^[ \t]*[0-9]+[ \t]+([^ \t].*)$",
                  "\\1"
                )
              )
              Builtins.y2milestone(
                "MX Priority decrased to maximal 65535 from %1",
                prio
              )
            end
          end
        end

        if tolower_type == "cname"
          key.value = TransformRecord(key.value)
          val.value = TransformRecord(val.value)
        elsif Builtins.contains(["ns", "mx"], tolower_type)
          val.value = TransformRecord(val.value)
        elsif tolower_type == "a"
          key.value = TransformRecord(key.value)
        end
      end

      true
    end
    def SwitchAndAdjustEditationWidgets(type, current_record, decoded_zone, zone)
      current_record = deep_copy(current_record)
      new_rr_rp = GetEditationWidgets(type.value)

      key = Convert.to_string(UI.QueryWidget(Id("add_record_name"), :Value))
      val = Convert.to_string(UI.QueryWidget(Id("add_record_val"), :Value))

      if !Builtins.haskey(current_record, "key")
        Ops.set(current_record, "key", key)
      end
      if !Builtins.haskey(current_record, "value")
        Ops.set(current_record, "value", val)
      end

      # Replacing the editation widgets
      if new_rr_rp != @current_rr_rp
        @current_rr_rp = deep_copy(new_rr_rp)
        UI.ReplaceWidget(Id("rr_rp"), @current_rr_rp)
        @last_add_record_type = type.value
        UI.ChangeWidget(Id("add_record_type"), :Value, type.value)
        UI.SetFocus(Id("add_record_type"))
      end

      decoded_zone_ref = arg_ref(decoded_zone.value)
      zone_ref = arg_ref(zone.value)
      AdjustEditationWidgets(current_record, decoded_zone_ref, zone_ref)
      decoded_zone.value = decoded_zone_ref.value
      zone.value = zone_ref.value

      nil
    end

    # Handle events in a tab of a dialog
    def HandleZoneRecordsTab(event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")
      zone_fqdn = Ops.add(Ops.get_string(@current_zone, "zone", ""), ".")

      r = Convert.to_integer(UI.QueryWidget(Id("records_list"), :CurrentItem))
      # Currently selected type
      type = Convert.to_string(UI.QueryWidget(Id("add_record_type"), :Value))

      # translating new record key
      key = Convert.to_string(UI.QueryWidget(Id("add_record_name"), :Value))
      if key == "@"
        key = zone_fqdn
        Builtins.y2warning("Transforming key @ into %1", key)
      end
      key = Punycode.EncodeDomainName(key)

      # translating new record val
      val = Punycode.EncodeDomainName(
        Convert.to_string(UI.QueryWidget(Id("add_record_val"), :Value))
      )

      record_service = ""
      record_protocol = ""

      record_prio = 0
      record_weigh = 0
      record_port = 0

      zone = Ops.get_string(@current_zone, "zone", "")
      decoded_zone = Punycode.DecodeDomainName(zone)

      # Switch to new type of Editation dialog
      if ret == "add_record_type"
        if type != @last_add_record_type
          type_ref = arg_ref(type)
          decoded_zone_ref = arg_ref(decoded_zone)
          zone_ref = arg_ref(zone)
          SwitchAndAdjustEditationWidgets(
            type_ref,
            { "type" => type },
            decoded_zone_ref,
            zone_ref
          )
          type = type_ref.value
          decoded_zone = decoded_zone_ref.value
          zone = zone_ref.value
        end
        return nil
      end

      case type
        when "SRV"
          record_service = Convert.to_string(
            UI.QueryWidget(Id("add_record_service"), :Value)
          )
          record_protocol = Convert.to_string(
            UI.QueryWidget(Id("add_record_protocol"), :Value)
          )

          # empty key or FQDN
          if key == "" || key == zone_fqdn
            key = Builtins.sformat("%1.%2", record_service, record_protocol) 
            # non empty key & not matching zone FQDN
          else
            key = Builtins.sformat(
              "%1.%2.%3",
              record_service,
              record_protocol,
              key
            )
          end

          record_prio = Convert.to_integer(
            UI.QueryWidget(Id("add_record_prio"), :Value)
          )
          record_weigh = Convert.to_integer(
            UI.QueryWidget(Id("add_record_weight"), :Value)
          )
          record_port = Convert.to_integer(
            UI.QueryWidget(Id("add_record_port"), :Value)
          )

          val = Builtins.sformat(
            "%1 %2 %3 %4",
            record_prio,
            record_weigh,
            record_port,
            val
          )
        when "MX"
          record_prio = Convert.to_integer(
            UI.QueryWidget(Id("add_record_prio"), :Value)
          )

          val = Builtins.sformat("%1 %2", record_prio, val)
        # "A", "AAAA", "CNAME", "NS", "PTR", "TXT", "SPF"
        else

      end

      # Switching selected record
      if ret == "records_list"
        # type might have changed
        type = Ops.get_string(@current_zone, ["records", r, "type"], "")
        type_ref = arg_ref(type)
        decoded_zone_ref = arg_ref(decoded_zone)
        zone_ref = arg_ref(zone)
        SwitchAndAdjustEditationWidgets(
          type_ref,
          Ops.get_map(@current_zone, ["records", r], {}),
          decoded_zone_ref,
          zone_ref
        )
        type = type_ref.value
        decoded_zone = decoded_zone_ref.value
        zone = zone_ref.value
      # Changing selected record
      elsif ret == "change_record"
        if (
            type_ref = arg_ref(type);
            key_ref = arg_ref(key);
            val_ref = arg_ref(val);
            _CheckAndModifyRecord_result = CheckAndModifyRecord(
              type_ref,
              key_ref,
              val_ref
            );
            type = type_ref.value;
            key = key_ref.value;
            val = val_ref.value;
            _CheckAndModifyRecord_result
          ) != true
          return nil
        end

        current_zone_ref = arg_ref(@current_zone)
        DnsServerHelperFunctions.HandleNsupdate(
          Ops.get_map(@current_zone, ["records", r], {}),
          "delete",
          current_zone_ref
        )
        @current_zone = current_zone_ref.value

        Ops.set(@current_zone, ["records", r, "key"], key)
        Ops.set(@current_zone, ["records", r, "type"], type)
        Ops.set(@current_zone, ["records", r, "value"], val)
        RedrawZonesTable()

        current_zone_ref = arg_ref(@current_zone)
        DnsServerHelperFunctions.HandleNsupdate(
          Ops.get_map(@current_zone, ["records", r], {}),
          "add",
          current_zone_ref
        )
        @current_zone = current_zone_ref.value
      # Adding new record
      elsif ret == "add_record"
        if (
            type_ref = arg_ref(type);
            key_ref = arg_ref(key);
            val_ref = arg_ref(val);
            _CheckAndModifyRecord_result = CheckAndModifyRecord(
              type_ref,
              key_ref,
              val_ref
            );
            type = type_ref.value;
            key = key_ref.value;
            val = val_ref.value;
            _CheckAndModifyRecord_result
          ) != true
          return nil
        end

        rec = { "key" => key, "type" => type, "value" => val }
        Ops.set(
          @current_zone,
          "records",
          Builtins.add(Ops.get_list(@current_zone, "records", []), rec)
        )
        RedrawZonesTable()

        current_zone_ref = arg_ref(@current_zone)
        DnsServerHelperFunctions.HandleNsupdate(rec, "add", current_zone_ref)
        @current_zone = current_zone_ref.value
      # Removing selected record
      elsif ret == "delete_record"
        return nil if !Confirm.DeleteSelected

        current_zone_ref = arg_ref(@current_zone)
        DnsServerHelperFunctions.HandleNsupdate(
          Ops.get_map(@current_zone, ["records", r], {}),
          "delete",
          current_zone_ref
        )
        @current_zone = current_zone_ref.value

        Ops.set(@current_zone, ["records", r], nil)
        Ops.set(
          @current_zone,
          "records",
          Builtins.filter(Ops.get_list(@current_zone, "records", [])) do |r2|
            r2 != nil
          end
        )
        RedrawZonesTable() 

        # And the rest...
      else
        Builtins.y2error("Uknown ret: %1", ret)
      end

      nil
    end
    # Dialog Zone Editor - Tab
    # @param [String] tab_id
    # @return [Yast::Term] dialog for ZoneEditorDialog()
    def GetMasterZoneEditorTab(tab_id)
      if tab_id == "basics"
        return GetMasterZoneEditorTabBasics()
      elsif tab_id == "name_servers"
        return GetMasterZoneEditorTabNameServers()
      elsif tab_id == "mail_servers"
        return GetMasterZoneEditorTabMailServers()
      elsif tab_id == "soa_settings"
        return GetMasterZoneEditorTabSOASettings()
      elsif tab_id == "records"
        return GetMasterZoneEditorTabRecords()
      end

      # This should never happen, but ...
      Builtins.y2error("unknown tab_id: %1", tab_id)
      # When no dialog defined for this tab (software error)
      Label(_("An internal error has occurred."))
    end

    def InitMasterZoneTab(dialog)
      if dialog == "basics"
        InitZoneBasicsTab()
      elsif dialog == "name_servers"
        InitNsListTab()
      elsif dialog == "mail_servers"
        InitMxListTab()
      elsif dialog == "soa_settings"
        InitSoaTab()
      elsif dialog == "records"
        InitZoneRecordsTab()
      end

      nil
    end

    def StoreMasterZoneTab(dialog)
      if dialog == "basics"
        StoreZoneBasicsTab()
      elsif dialog == "name_servers"
        StoreNsListTab()
      elsif dialog == "mail_servers"
        StoreMxListTab()
      elsif dialog == "soa_settings"
        StoreSoaTab()
      elsif dialog == "records"
        StoreZoneRecordsTab()
      end

      nil
    end

    def HandleMasterZoneTab(dialog, event)
      event = deep_copy(event)
      ret = nil
      if dialog == "basics"
        HandleZoneBasicsTab(event)
      elsif dialog == "name_servers"
        ret = HandleNsListTab(event)
      elsif dialog == "mail_servers"
        ret = HandleMxListTab(event)
      elsif dialog == "soa_settings"
        ret = HandleSoaTab(event)
      elsif dialog == "records"
        HandleZoneRecordsTab(event)
      end
      ret
    end

    def ValidateMasterZoneTab(dialog, event)
      event = deep_copy(event)
      ret = true
      if dialog == "basics"
        ret = true
      elsif dialog == "name_servers"
        ret = true
      elsif dialog == "mail_servers"
        ret = true
      elsif dialog == "soa_settings"
        ret = ValidateSoaTab(event)
      elsif dialog == "records"
        ret = true
      end
      ret
    end
    # Dialog Zone Editor - Main
    # @return [Object] dialog result for wizard
    def runMasterZoneTabDialog
      # Dialog Caption - Expert Settings - Zone Editor
      caption = _("Zone Editor")

      # Helps ale linked like this Tab_ID -> HELPS[ Help_ID ]
      help_identificators = {
        "basics"       => "zone_editor_basics",
        "name_servers" => "zone_editor_nameservers",
        "mail_servers" => "zone_editor_mailservers",
        "soa_settings" => "zone_editor_soa",
        "records"      => "zone_editor_records"
      }

      zone_name = Ops.get_string(@current_zone, "zone", "")
      zone_name_dec = Punycode.DecodeDomainName(zone_name)
      current_tab = "basics"

      tab_terms = []

      # Different list of tabs for reverse zone
      if DnsServerHelperFunctions.IsReverseZone(zone_name)
        tab_terms = [
          # Menu Item - Zone Editor - Tab
          Item(Id("basics"), _("&Basics")),
          # Menu Item - Zone Editor - Tab
          Item(Id("name_servers"), _("NS Recor&ds")),
          # Menu Item - Zone Editor - Tab
          Item(Id("soa_settings"), _("&SOA")),
          # Menu Item - Zone Editor - Tab
          Item(Id("records"), _("R&ecords"))
        ] 
        # Not a reverse zone
      else
        tab_terms = [
          # Menu Item - Zone Editor - Tab
          Item(Id("basics"), _("&Basics")),
          # Menu Item - Zone Editor - Tab
          Item(Id("name_servers"), _("NS Recor&ds")),
          # Menu Item - Zone Editor - Tab
          Item(Id("mail_servers"), _("M&X Records")),
          # Menu Item - Zone Editor - Tab
          Item(Id("soa_settings"), _("&SOA")),
          # Menu Item - Zone Editor - Tab
          Item(Id("records"), _("R&ecords"))
        ]
      end



      contents =
        #`Top (
        VBox(
          Opt(:hvstretch),
          HBox(
            # Label - connected with Textentry which shows current edited zone
            HSquash(Label(_("Settings for Zone"))),
            HSquash(
              MinWidth(
                Ops.add(Builtins.size(zone_name_dec), 3),
                InputField(
                  Id("current_zone"),
                  Opt(:disabled, :hstretch),
                  "",
                  zone_name_dec
                )
              )
            ),
            HStretch()
          ),
          VSpacing(1),
          # Here start Tabs
          # FIXME: after `Tab implementation
          UI.HasSpecialWidget(:DumbTab) ?
            DumbTab(
              Id(:dumbtab),
              tab_terms,
              ReplacePoint(
                Id(:tabContents),
                GetMasterZoneEditorTab(current_tab)
              )
            ) :
            DnsFakeTabs.DumbTabs(
              tab_terms,
              ReplacePoint(
                Id(:tabContents),
                GetMasterZoneEditorTab(current_tab)
              )
            )
        )
      #);
      # Menu Item - Zone Editor - Tab
      qwerty = _("Ad&vanced")
      # error report
      #qwerty = _("The input value is invalid.");
      # error report
      #qwerty = _("At least one name server must be defined.");

      # FIXME: Only one help is used for all tabs. Maybe would be better to change the help for every single tab.
      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get_string(
          @HELPS,
          Ops.get(help_identificators, current_tab, ""),
          ""
        ),
        Label.BackButton,
        Label.OKButton
      )
      Wizard.DisableBackButton
      Wizard.SetAbortButton(:go_back, Label.CancelButton)
      InitMasterZoneTab(current_tab)

      event = nil
      ret = nil
      while true
        event = UI.WaitForEvent
        ret = Ops.get(event, "ID")

        if ret == :next
          # The new ones are alerady stored there
          if current_tab != "name_servers"
            # BNC #436456
            StoreZoneBasicsTab() if current_tab == "basics"

            RegenerateCurrentZoneNS()
          end

          # at least one NS server must be set
          if Builtins.size(@current_zone_ns) == 0
            Builtins.y2warning("At least one NS server must be set")
            current_tab = "name_servers"
            UI.ReplaceWidget(
              :tabContents,
              GetMasterZoneEditorTab("name_servers")
            )
            if UI.HasSpecialWidget(:DumbTab)
              UI.ChangeWidget(Id(:dumbtab), :CurrentItem, current_tab)
            end
            Report.Error(_("At least one NS server must be set."))
            next
          end

          if ValidateMasterZoneTab(current_tab, event)
            break
          else
            next
          end
        end
        if ret == :go_back
          ret = :back
          break
        # close the whole dialog
        elsif ret == :cancel
          if ReallyAbort()
            return :abort
          else
            next
          end
        # TAB fake
        elsif ret == "basics" || ret == "name_servers" || ret == "mail_servers" ||
            ret == "soa_settings" ||
            ret == "records"
          if ValidateMasterZoneTab(current_tab, event)
            StoreMasterZoneTab(current_tab)
            current_tab = Convert.to_string(ret)

            show_warning = ""

            autogenerated_reverse_zone_allows = [
              "basics",
              "soa_settings",
              "name_servers"
            ]

            # Fake current tab if selected tab not allowed
            if Ops.get_string(
                # connected_with i set
                @current_zone,
                "connected_with",
                ""
              ) != "" &&
                Ops.get(@current_zone, "connected_with") != nil &&
                !# switching to forbidden tab
                Builtins.contains(
                  autogenerated_reverse_zone_allows,
                  Builtins.tostring(ret)
                )
              current_tab = "basics"
              if UI.HasSpecialWidget(:DumbTab)
                UI.ChangeWidget(Id(:dumbtab), :CurrentItem, current_tab)
              end
              Builtins.y2warning(
                "connected_with has been set, setting '%1' is not allowed",
                ret
              )
              # warning message, %1 is replaced with a zone name
              #
              # Automatically Generate Records From is a feature that makes YaST to generate
              # DNS records manually from selected zone
              show_warning = Builtins.sformat(
                _(
                  "Current zone records are automatically generated from %1 zone.\nTo change records manually disable the Automatically Generate Records From feature."
                ),
                Ops.get_string(@current_zone, "connected_with", "")
              )
            end

            # Switch contents
            UI.ReplaceWidget(:tabContents, GetMasterZoneEditorTab(current_tab))

            if current_tab == "records"
              help_part2 = "zone_editor_records_forward"
              if DnsServerHelperFunctions.IsReverseZone(
                  Ops.get_string(@current_zone, "zone", "")
                )
                help_part2 = "zone_editor_records_reverse"
              end

              Wizard.RestoreHelp(
                Ops.add(
                  Ops.get_string(
                    @HELPS,
                    Ops.get(help_identificators, current_tab, ""),
                    ""
                  ),
                  Ops.get_string(@HELPS, help_part2, "")
                )
              )
            else
              Wizard.RestoreHelp(
                Ops.get_string(
                  @HELPS,
                  Ops.get(help_identificators, current_tab, ""),
                  ""
                )
              )
            end

            # Initialize values
            InitMasterZoneTab(current_tab)

            # Show warning if anything to show
            Report.Warning(show_warning) if show_warning != ""
          else
            # ensure the same tab selected
            if UI.HasSpecialWidget(:DumbTab)
              UI.ChangeWidget(Id(:dumbtab), :CurrentItem, current_tab)
            end
          end
        else
          ret = HandleMasterZoneTab(current_tab, event)
          break if ret != nil
        end
      end

      if ret == :next
        StoreMasterZoneTab(current_tab)
        Ops.set(@current_zone, "modified", true)
        DnsServer.StoreCurrentZone(@current_zone)
        DnsServer.StoreZone
        DnsServer.SetModified
      end

      @was_editing_zone = true
      Convert.to_symbol(ret)
    end

    # Dialog Zone Editor - Slave
    # @return [Object] dialog result for wizard
    def runSlaveZoneTabDialog
      acl = Builtins.maplist(DnsServer.GetAcl) do |acl_record|
        acl_splitted = Builtins.splitstring(acl_record, " \t")
        Ops.get(acl_splitted, 0, "")
      end
      acl = Convert.convert(
        Builtins.sort(
          Builtins.merge(acl, ["any", "none", "localhost", "localnets"])
        ),
        :from => "list",
        :to   => "list <string>"
      )

      # bug #203910
      # hide "none" from listed ACLs
      # "none" means, not allowed and thus multiselectbox of ACLs is disabled
      acl = Builtins.filter(acl) { |one_acl| one_acl != "none" }

      zone_name = Ops.get_string(@current_zone, "zone", "")
      contents = VBox(
        HBox(
          # Label - connected with Textentry which shows current edited zone
          HSquash(Label(_("Settings for Zone"))),
          HSquash(
            InputField(
              Id("current_zone"),
              Opt(:disabled, :hstretch),
              "",
              Punycode.DecodeDomainName(zone_name)
            )
          ),
          HStretch()
        ),
        VSpacing(1),
        # TRANSLATORS: Text entry
        Left(
          InputField(Id("master"), Opt(:hstretch), _("&Master DNS Server IP"))
        ),
        VSpacing(2),
        Left(
          CheckBox(
            Id("enable_zone_transport"),
            Opt(:notify),
            # check box
            _("Enable &Zone Transport")
          )
        ),
        # multi selection box
        VSquash(MultiSelectionBox(Id("acls_list"), _("ACLs"), acl)),
        VStretch()
      )

      # dialog caption
      caption = _("Zone Editor")

      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get_string(@HELPS, "slave_zone", ""),
        Label.CancelButton,
        Label.OKButton
      )

      event = {}
      ret = nil
      ZoneAclInit()
      zm = Ops.get_string(@current_zone, "masters", "")
      i = Builtins.findfirstof(zm, "{")
      zm = Builtins.substring(zm, Ops.add(i, 1)) if i != nil
      i = Builtins.findfirstof(zm, "}")
      zm = Builtins.substring(zm, 0, i) if i != nil
      @current_zone_masters = Builtins.splitstring(zm, ";")
      @current_zone_masters = Builtins.maplist(@current_zone_masters) do |m|
        Builtins.mergestring(Builtins.splitstring(m, " "), "")
      end
      @current_zone_masters = Builtins.filter(@current_zone_masters) do |m|
        m != ""
      end
      UI.ChangeWidget(
        Id("master"),
        :Value,
        Ops.get(@current_zone_masters, 0, "")
      )
      UI.ChangeWidget(Id("master"), :ValidChars, "0123456789.")
      while true
        event = UI.WaitForEvent
        ret = Ops.get(event, "ID")
        ZoneAclHandle(event)
        if ret == :abort
          if ReallyAbort()
            return :abort
          else
            next
          end
        end
        if ret == :back
          # fixing bug #45950, slave zone _MUST_ have master server
          if Builtins.size(@current_zone_masters) == 0
            if Popup.ContinueCancelHeadline(
                # TRANSLATORS: Popup error headline
                _("Missing Master Server"),
                # TRANSLATORS: Popup error text
                _(
                  "Every slave zone must have its master server IP defined.\n" +
                    "Configuration of a DNS server without a master server would fail.\n" +
                    "If you continue, the current zone will be removed."
                )
              )
              # removing current zone - zone needs master server
              @zones = Builtins.filter(@zones) { |z| z != @current_zone }
              DnsServer.StoreZones(@zones)
              break
            else
              next
            end
          end

          break
        end
        if ret == :next
          if false
            # TRANSLATORS: A popup error message
            Report.Error(_("No master DNS server defined."))
            next
          else
            # controlling sever name, IP
            master_server = Convert.to_string(
              UI.QueryWidget(Id("master"), :Value)
            )
            # Master server must be only IP
            if IP.Check4(master_server) != true
              UI.SetFocus(Id("master"))
              # A popup error message
              Popup.Error(
                _("The specified master name server is not a valid IP address.")
              )
              next
            end
            break
          end
        end
      end
      if ret == :next
        Ops.set(
          @current_zone,
          "masters",
          Builtins.sformat(
            "{ %1; }",
            Convert.to_string(UI.QueryWidget(Id("master"), :Value))
          )
        )
        ZoneAclStore()
        Ops.set(@current_zone, "modified", true)
        DnsServer.StoreCurrentZone(@current_zone)
        DnsServer.StoreZone
        DnsServer.SetModified
      end
      @was_editing_zone = true
      Convert.to_symbol(ret)
    end

    # Dialog Zone Editor - Stub
    # @return [Object] dialog result for wizard
    def runStubZoneTabDialog
      @was_editing_zone = true
      runSlaveZoneTabDialog
    end

    def InitTableOfZOneForwarders
      if @current_zone_forwarders != nil && @current_zone_forwarders != []
        forwarders_items = []
        Builtins.foreach(@current_zone_forwarders) do |one_forwarder|
          forwarders_items = Builtins.add(
            forwarders_items,
            Item(Id(one_forwarder), one_forwarder)
          )
        end
        UI.ChangeWidget(Id("zone_forwarders_list"), :Items, forwarders_items)
      end

      nil
    end

    def ForwardZone_AddZoneForwarder
      new_forwarder = Convert.to_string(
        UI.QueryWidget(Id("new_forwarder"), :Value)
      )
      if !IP.Check4(new_forwarder)
        UI.SetFocus(Id("new_forwarder"))
        Report.Error(IP.Valid4)
      else
        @current_zone_forwarders = Builtins.toset(
          Builtins.add(@current_zone_forwarders, new_forwarder)
        )
        InitTableOfZOneForwarders()
      end

      nil
    end

    def ForwardZone_DeleteZoneForwarder
      delete_forwarder = Convert.to_string(
        UI.QueryWidget(Id("zone_forwarders_list"), :CurrentItem)
      )
      if delete_forwarder != nil && delete_forwarder != ""
        @current_zone_forwarders = Builtins.filter(@current_zone_forwarders) do |one_forwarder|
          one_forwarder != delete_forwarder
        end
        InitTableOfZOneForwarders()
      end

      nil
    end

    # Dialog Zone Editor - Forward
    # @return [Object] dialog result for wizard
    def runForwardZoneTabDialog
      zone_name = Ops.get_string(@current_zone, "zone", "")
      @current_zone_forwarders = DnsServerAPI.GetZoneForwarders(
        Ops.get_string(@current_zone, "zone", "")
      )

      contents = VBox(
        HBox(
          # Label - connected with Textentry which shows current edited zone
          HSquash(Label(_("Settings for Zone"))),
          HSquash(
            InputField(
              Id("current_zone"),
              Opt(:disabled, :hstretch),
              "",
              Punycode.DecodeDomainName(zone_name)
            )
          ),
          HStretch()
        ),
        VSpacing(1),
        VSquash(
          HBox(
            HWeight(
              7,
              # Textentry - adding forwarder
              InputField(
                Id("new_forwarder"),
                Opt(:hstretch),
                _("New &Forwarder IP Address")
              )
            ),
            HWeight(
              2,
              VBox(
                VStretch(),
                VSquash(
                  PushButton(
                    Id("add_forwarder"),
                    Opt(:hstretch),
                    Label.AddButton
                  )
                )
              )
            )
          )
        ),
        HBox(
          HWeight(
            7,
            # Selectionbox - listing current forwarders
            SelectionBox(
              Id("zone_forwarders_list"),
              Opt(:hstretch),
              _("Current &Zone Forwarders"),
              []
            )
          ),
          HWeight(
            2,
            VBox(
              VSquash(VSpacing(1)),
              VSquash(
                PushButton(
                  Id("delete_forwarder"),
                  Opt(:hstretch),
                  Label.DeleteButton
                )
              ),
              VStretch()
            )
          )
        )
      )

      # dialog caption
      caption = _("Forward Zone Editor")

      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get_string(@HELPS, "forward_zone", ""),
        Label.CancelButton,
        Label.OKButton
      )
      UI.ChangeWidget(Id("new_forwarder"), :ValidChars, IP.ValidChars4)

      InitTableOfZOneForwarders()

      ret = nil

      while true
        ret = UI.UserInput

        if ret == :abort || ret == :cancel
          if ReallyAbort()
            return :abort
          else
            next
          end
        elsif ret == :back
          break
        elsif ret == "add_forwarder"
          ForwardZone_AddZoneForwarder()
          next
        elsif ret == "delete_forwarder"
          ForwardZone_DeleteZoneForwarder()
          next
        elsif ret == :next
          if Builtins.size(@current_zone_forwarders) == 0
            # TRANSLATORS: popup question
            if !Popup.YesNo(
                _(
                  "This forward zone has no forwarders defined, which means\n" +
                    "that all DNS queries for this zone are denied.\n" +
                    "Really deny these queries?"
                )
              )
              next
            end
          end

          Builtins.y2milestone(
            "Zone %1 (%2), Forwarders: %3",
            Ops.get_string(@current_zone, "zone", ""),
            Punycode.DecodeDomainName(Ops.get_string(@current_zone, "zone", "")),
            @current_zone_forwarders
          )
          Ops.set(@current_zone, "modified", true)
          if Ops.greater_than(Builtins.size(@current_zone_forwarders), 0)
            Ops.set(
              @current_zone,
              "forwarders",
              Builtins.sformat(
                "{ %1; }",
                Builtins.mergestring(@current_zone_forwarders, "; ")
              )
            )
          else
            Ops.set(@current_zone, "forwarders", "{}")
          end
          DnsServer.StoreCurrentZone(@current_zone)
          DnsServer.StoreZone
          DnsServer.SetModified
          break
        else
          Builtins.y2error("Unexpected return %1", ret)
        end
      end

      Ops.set(@current_zone, "modified", true) if ret == :next
      # empty the list
      @current_zone_forwarders = []
      @was_editing_zone = true

      Convert.to_symbol(ret)
    end
  end
end
