# encoding: utf-8

# File:	modules/DnsServer.ycp
# Package:	Configuration of dns-server
# Summary:	Data for configuration of dns-server, input and output functions.
# Authors:	Jiri Srain <jsrain@suse.cz>

require "ui/service_status"

module Yast
  # Representation of the configuration of dns-server.
  # Input and output routines.
  module DnsServerDialogMainInclude
    def initialize_dns_server_dialog_main(include_target)
      textdomain "dns-server"

      Yast.import "DnsServer"
      Yast.import "IP"
      Yast.import "Hostname"
      Yast.import "Popup"
      Yast.import "Label"
      Yast.import "CWM"
      Yast.import "Wizard"
      Yast.import "DialogTree"
      Yast.import "CWMServiceStart"
      Yast.import "Mode"
      Yast.import "Report"
      Yast.import "CWMFirewallInterfaces"
      Yast.import "Message"
      Yast.import "DnsRoutines"
      Yast.import "CWMTsigKeys"
      Yast.import "DnsTsigKeys"
      Yast.import "Confirm"
      Yast.import "DnsServerAPI"
      Yast.import "Punycode"
      Yast.import "DnsServerHelperFunctions"
      Yast.import "String"

      # String defines the initial screen for the expert dialog
      @initial_screen = "start_up"

      @global_options_add_items = Builtins.sort(
        [
          "additional-from-auth",
          "additional-from-cache",
          "allow-query",
          "allow-recursion",
          "allow-transfer",
          "also-notify",
          "auth-nxdomain",
          "blackhole",
          "check-names",
          "cleaning-interval",
          "coresize",
          "datasize",
          "deallocate-on-exit",
          "dialup",
          "directory",
          "dump-file",
          "fake-iquery",
          "fetch-glue",
          "files",
          "forward",
          "forwarders",
          "has-old-clients",
          "heartbeat-interval",
          "host-statistics",
          "host-statistics-max",
          "hostname",
          "interface-interval",
          "lame-ttl",
          "listen-on",
          "listen-on-v6",
          "maintain-ixfr-base",
          "match-mapped-addresses",
          "max-cache-size",
          "max-cache-ttl",
          "max-ixfr-log-size",
          "max-ncache-ttl",
          "max-refresh-time",
          "max-retry-time",
          "max-transfer-idle-in",
          "max-transfer-idle-out",
          "max-transfer-time-in",
          "max-transfer-time-out",
          "memstatistics-file",
          "min-refresh-time",
          "min-retry-time",
          "min-roots",
          "minimal-responses",
          "multiple-cnames",
          "named-xfer",
          "notify",
          "pid-file",
          "port",
          "preferred-glue",
          "provide-ixfr",
          "query-source",
          "random-device",
          "recursion",
          "recursive-clients",
          "request-ixfr",
          "rfc2308-type1",
          "rrset-order",
          "serial-queries",
          "serial-query-rate",
          "sig-validity-interval",
          "sortlist",
          "stacksize",
          "statistics-file",
          "statistics-interval",
          "suppress-initial-notify",
          "tcp-clients",
          "tkey-dhkey",
          "tkey-domain",
          "topology",
          "transfer-format",
          "transfer-source",
          "transfers-in",
          "transfers-out",
          "transfers-per-ns",
          "treat-cr-as-space",
          "use-id-pool",
          "use-ixfr",
          "version",
          "zone-statistics"
        ]
      )

      @global_options_unique_items = Builtins.sort(
        [
          "additional-from-auth",
          "additional-from-cache",
          "auth-nxdomain",
          "cleaning-interval",
          "coresize",
          "datasize",
          "deallocate-on-exit",
          "dialup",
          "directory",
          "dump-file",
          "fake-iquery",
          "fetch-glue",
          "files",
          "forward",
          "has-old-clients",
          "heartbeat-interval",
          "host-statistics",
          "interface-interval",
          "lame-ttl",
          "maintain-ixfr-base",
          "match-mapped-addresses",
          "max-cache-size",
          "max-cache-ttl",
          "max-ixfr-log-size",
          "max-ncache-ttl",
          "max-refresh-time",
          "max-retry-time",
          "max-transfer-idle-in",
          "max-transfer-idle-out",
          "max-transfer-time-in",
          "max-transfer-time-out",
          "memstatistics-file",
          "min-refresh-time",
          "min-retry-time",
          "min-roots",
          "minimal-responses",
          "multiple-cnames",
          "named-xfer",
          "notify",
          "pid-file",
          "port",
          "provide-ixfr",
          "random-device",
          "recursion",
          "recursive-clients",
          "request-ixfr",
          "rfc2308-type1",
          "serial-queries",
          "serial-query-rate",
          "sig-validity-interval",
          "stacksize",
          "statistics-file",
          "statistics-interval",
          "tcp-clients",
          "tkey-dhkey",
          "tkey-domain",
          "transfer-format",
          "transfers-in",
          "transfers-out",
          "transfers-per-ns",
          "treat-cr-as-space",
          "use-id-pool",
          "use-ixfr",
          "version",
          "zone-statistics"
        ]
      )

      @global_options_yesno_items = Builtins.sort(
        [
          "zone-statistics",
          "auth-nxdomain",
          "deallocate-on-exit",
          "fake-iquery",
          "fetch-glue",
          "has-old-clients",
          "host-statistics",
          "minimal-responses",
          "multiple-cnames",
          "recursion",
          "rfc2308-type1",
          "use-id-pool",
          "maintain-ixfr-base",
          "use-ixfr",
          "provide-ixfr",
          "request-ixfr",
          "treat-cr-as-space",
          "additional-from-auth",
          "additional-from-cache",
          "match-mapped-addresses"
        ]
      )

      @global_options_number_items = Builtins.sort(
        [
          "max-transfer-time-in",
          "max-transfer-time-out",
          "max-transfer-idle-in",
          "max-transfer-idle-out",
          "tcp-clients",
          "recursive-clients",
          "serial-query-rate",
          "serial-queries",
          "transfers-in",
          "transfers-out",
          "transfers-per-ns",
          "max-ixfr-log-size",
          "cleaning-interval",
          "heartbeat-interval",
          "interface-interval",
          "statistics-interval",
          "lame-ttl",
          "max-ncache-ttl",
          "max-cache-ttl",
          "sig-validity-interval",
          "min-roots",
          "min-refresh-time",
          "max-refresh-time",
          "min-retry-time",
          "max-retry-time"
        ]
      )

      # Dialog label DNS - expert settings
      @dns_server_label = _("DNS Server")


      @functions = { :abort => fun_ref(method(:confirmAbort), "boolean ()") }
    end

    def InitStartUp(_key)
      status_widget.refresh
      nil
    end

    def HandleStartUp(_key, event)
      event_id = event["ID"]
      if event_id == "apply"
        SaveAndRestart()
      else
        if status_widget.handle_input(event_id) == :enabled_flag
          DnsServer.SetStartService(status_widget.enabled_flag?)
        end
      end
      nil
    end

    # Sets the dialog icon
    def InitDNSSErverIcon(key)
      SetDNSSErverIcon()

      nil
    end

    # Dialog Expert Settings - Forwarders
    # @return [Yast::Term] for Get_ExpertDialog()
    def ExpertForwardersDialog
      dialog = VBox(
        # label
        VBox(
          HBox(
            ComboBox(
              Id("forwarder_policy"),
              Opt(:notify),
              # T: ComboBox label
              _("Local DNS Resolution &Policy"),
              [
                # T: ComboBox item
                Item(Id(:nomodify), _("Merging forwarders is disabled")),
                # T: ComboBox item
                Item(Id(:auto),     _("Automatic merging")),
                # T: ComboBox item
                Item(Id(:static),   _("Merging forwarders is enabled")),
                # T: ComboBox item
                Item(Id(:custom),   _("Custom configuration"))
              ]
            ),
            HSpacing(1),
            InputField(Id("custom_policy"), Opt(:hstretch), _("Custom policy"))
          ),
          VSpacing(1),
          Left(
            ComboBox(
              Id("forwarder"),
              # T: ComboBox label
              _("Local DNS Resolution &Forwarder"),
              [
                # T: ComboBox item
                Item(Id(:resolver), _("Using system name servers")),
                # T: ComboBox item
                Item(Id(:bind),     _("This name server (bind)")),
                # T: ComboBox item
                Item(Id(:dnsmasq),  _("Local dnsmasq server")),
              ]
            )
          )
        ),
        VSpacing(1),
        # Frame label for DNS-Forwarders options
        VSquash(
          Frame(
            # Frame label for DNS-Forwarders adding IP
            _("Add IP Address"),
            VBox(
              HBox(
                HWeight(
                  9,
                  # Textentry for DNS-Forwarders adding IP
                  InputField(
                    Id("forwarders_new_ip_address"),
                    Opt(:hstretch),
                    _("IPv4 or IPv6 A&ddress"),
                    ""
                  )
                ),
                HWeight(
                  2,
                  Bottom(
                    PushButton(
                      Id("forwarders_add_ip_address"),
                      Opt(:hstretch),
                      Label.AddButton
                    )
                  )
                )
              ),
              VSpacing(0.5)
            )
          )
        ),
        VSpacing(0.5),
        HBox(
          HWeight(
            9,
            ReplacePoint(
              Id("forwarders_list_rp"),
              SelectionBox(
                Id("forwarders_list"),
                Opt(:hstretch),
                # Selectionbox for listing current DNS-Forwarders
                _("Forwarder &List"),
                []
              )
            )
          ),
          HWeight(
            2,
            VBox(
              VSquash(VSpacing(1)),
              VSquash(
                PushButton(
                  Id("forwarders_delete_ip_address"),
                  Opt(:hstretch),
                  Label.DeleteButton
                )
              ),
              VStretch()
            )
          )
        )
      )
      deep_copy(dialog)
    end

    def RedrawForwardersListWidget
      UI.ReplaceWidget(
        Id("forwarders_list_rp"),
        SelectionBox(
          Id("forwarders_list"),
          Opt(:hstretch),
          # Selectionbox for listing current DNS-Forwarders
          _("Forwarder &List"),
          @forwarders
        )
      )
      enabled = :nomodify !=
        Convert.to_symbol(UI.QueryWidget(Id("forwarder_policy"), :Value))
      UI.ChangeWidget(
        Id("forwarders_delete_ip_address"),
        :Enabled,
        @forwarders != [] && enabled
      )
      UI.ChangeWidget(Id("forwarders_list"), :Enabled, enabled)
      if @forwarders != [] && enabled
        UI.ChangeWidget(
          Id("forwarders_list"),
          :CurrentItem,
          Ops.get(@forwarders, 0, "")
        )
      end

      nil
    end

    def ReadForwarders
      options = DnsServer.GetGlobalOptions
      Builtins.foreach(options) do |o|
        if Ops.get_string(o, "key", "") == "forwarders"
          @forwarders = Builtins.splitstring(
            Ops.get_string(o, "value", ""),
            " "
          )
          @forwarders = Builtins.filter(@forwarders) do |f|
            !Builtins.issubstring(f, "{") && !Builtins.issubstring(f, "}") &&
              f != ""
          end
          @forwarders = Builtins.maplist(@forwarders) do |f|
            i = Builtins.findfirstof(f, ";")
            f = Builtins.substring(f, 0, i) if i != nil
            f
          end
        end
      end

      nil
    end

    # Setting `ValidChars for the dialog
    def ValidCharsForwardersPage
      # setting `ValidChars
      UI.ChangeWidget(
        Id("forwarders_new_ip_address"),
        :ValidChars,
        Ops.add(IP.ValidChars4, IP.ValidChars6)
      )

      nil
    end

    def handlePolicy(policy)
      if policy == :nomodify
        UI.ChangeWidget(Id("custom_policy"), :Enabled, false)
        UI.ChangeWidget(Id("custom_policy"), :Value, "")
        UI.ChangeWidget(Id("forwarders_new_ip_address"), :Enabled, false)
        UI.ChangeWidget(Id("forwarders_add_ip_address"), :Enabled, false)
        UI.ChangeWidget(Id("forwarder"), :Enabled, false)
      else
        if policy == :custom
          # preinitialize with STATIC
          UI.ChangeWidget(Id("custom_policy"), :Value, "STATIC")
          UI.ChangeWidget(Id("custom_policy"), :Enabled, true)
        else
          if policy == :static
            UI.ChangeWidget(Id("custom_policy"), :Value, "STATIC")
          elsif policy == :auto
            UI.ChangeWidget(Id("custom_policy"), :Value, "auto")
          end
          UI.ChangeWidget(Id("custom_policy"), :Enabled, false)
        end

        UI.ChangeWidget(Id("forwarders_new_ip_address"), :Enabled, true)
        UI.ChangeWidget(Id("forwarders_add_ip_address"), :Enabled, true)
        UI.ChangeWidget(Id("forwarder"), :Enabled, true)
      end

      nil
    end

    def initialize_local_forwarder
      local_forwarder = DnsServer.GetLocalForwarder

      if local_forwarder != DnsServerUIClass::PREFERRED_LOCAL_FORWARDER && DnsServer.first_run
        Builtins.y2milestone(
          "Current local forwarder: #{local_forwarder}, proposing new: #{DnsServerUIClass::PREFERRED_LOCAL_FORWARDER}"
        )
        local_forwarder = DnsServerUIClass::PREFERRED_LOCAL_FORWARDER
      end

      UI.ChangeWidget(Id("forwarder"), :Value, local_forwarder.to_sym)
    end

    # Initialize the tab of the dialog
    def InitExpertForwardersPage(key)
      SetDNSSErverIcon()

      UI.ChangeWidget(Id("custom_policy"), :Enabled, false)
      policy = DnsServer.GetNetconfigDNSPolicy
      policy_symb = :Empty

      if policy == nil || policy == ""
        policy_symb = :nomodify
      elsif policy == "auto" || policy == "STATIC *"
        policy_symb = :auto
      elsif policy == "STATIC"
        policy_symb = :static
      else
        policy_symb = :custom
      end

      UI.ChangeWidget(Id("forwarder_policy"), :Value, policy_symb)
      handlePolicy(policy_symb)
      initialize_local_forwarder
      ReadForwarders()
      RedrawForwardersListWidget()
      ValidCharsForwardersPage()

      nil
    end

    # Store settings of a tab of a dialog
    def StoreExpertForwardersPage(key, event)
      event = deep_copy(event)

      policy = Convert.to_symbol(UI.QueryWidget(Id("forwarder_policy"), :Value))
      new_dns_policy = case policy
        when :custom   then UI.QueryWidget(Id("custom_policy"), :Value)
        when :auto     then "auto"
        when :static   then "static"
        when :nomodify then ""
        else raise ArgumentError.new("Unknown forwarder_policy '#{policy}'")
      end
      DnsServer.SetNetconfigDNSPolicy(new_dns_policy)

      forwarder = (UI.QueryWidget(Id("forwarder"), :Value)).to_s
      if ! DnsServer.SetLocalForwarder(forwarder)
        Report.Error(_("Cannot set local forwarder to %{forwarder}") % { 'forwarder' => forwarder })
      end

      options = DnsServer.GetGlobalOptions
      options = Builtins.filter(options) do |o|
        Ops.get_string(o, "key", "") != "forwarders" # && o["key"]:"" != "forward"
      end
      if @forwarders != []
        forwarders_str = Builtins.mergestring(@forwarders, "; ")
        forwarders_str = Builtins.sformat("{ %1; }", forwarders_str)
        options = Builtins.add(
          options,
          { "key" => "forwarders", "value" => forwarders_str }
        )
      end

      DnsServer.SetGlobalOptions(options)

      nil
    end

    # Returns list of IPs currently used by the system.
    #
    # @param boolean whether local addresses should be returned as well (the default is false)
    def CurrentlyUsedIPs(including_local)
      cmd = "ip addr show | grep 'inet\\(6\\)\\?' | sed 's/^[ \\t]\\+inet\\(6\\)\\?[ \\t]\\+\\([^\\/]\\+\\)\\/.*$/\\2/'"
      cmd_ret = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))

      if cmd_ret == nil || Ops.get_integer(cmd_ret, "exit", -1) != 0
        Builtins.y2error("Cannot get list of used IPs: %1", cmd_ret)
        return nil
      end

      used_ips = String.NewlineItems(Ops.get_string(cmd_ret, "stdout", ""))

      # Filtering out all local IPs
      used_ips = Builtins.filter(used_ips) do |used_ip|
        !Builtins.regexpmatch(used_ip, "127.0.0..*") && used_ip != "::1"
      end if including_local != true

      deep_copy(used_ips)
    end

    # Gets an IP address and returns it's local equivalent: 127.0.0.1 for IPv4, ::1 for IPv6.
    # If a given string is neither IPv4 nor IPv6, nil is returned.
    #
    # @param string IP to transform
    # @return [String] transformed IP
    def ChangeIPToLocalEquivalent(ip_address)
      ret = nil

      if IP.Check4(ip_address)
        ret = "127.0.0.1"
      elsif IP.Check6(ip_address)
        ret = "::1"
      else
        ret = nil
      end

      Builtins.y2warning("Transforming forwarder IP %1 to %2", ip_address, ret)

      if ret == nil
        # An error message, %1 is replaced with a variable IP
        Report.Error(
          Builtins.sformat(_("Cannot find local equivalent for IP %1."), ret)
        )
      else
        # TRANSLATORS: A warning message, %1 is replaced with the input IP, %2 with the output IP
        Report.Warning(
          Builtins.sformat(
            _(
              "Forwarding DNS queries to itself would create an infinite loop.\n" +
                "IP address %1 is currently used by this server, so it has\n" +
                "been changed to its local equivalent %2."
            ),
            ip_address,
            ret
          )
        )
      end

      ret
    end

    # Handle events in a tab of a dialog
    def HandleExpertForwardersPage(key, event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")

      if ret == "forwarders_add_ip_address"
        new_addr = Convert.to_string(
          UI.QueryWidget(Id("forwarders_new_ip_address"), :Value)
        )
        # both IPv4 and IPv6
        if !IP.Check(new_addr)
          Report.Error(
            Ops.add(
              Ops.add(
                Ops.add(_("Invalid IPv4 or IPv6 address.") + "\n", IP.Valid4),
                "\n"
              ),
              _(
                "A valid IPv6 address consists of letters a-f, numbers,\nand colons."
              )
            )
          )
          return nil
        end

        used_ips = CurrentlyUsedIPs(false)
        if Builtins.contains(used_ips, new_addr)
          new_addr = ChangeIPToLocalEquivalent(new_addr)
          return nil if new_addr == nil
        end

        if Builtins.contains(@forwarders, new_addr)
          # error report
          Report.Error(_("The specified forwarder is already present."))
          return nil
        end
        @forwarders = Builtins.add(@forwarders, new_addr)
      elsif ret == "forwarders_delete_ip_address"
        old_addr = Convert.to_string(
          UI.QueryWidget(Id("forwarders_list"), :CurrentItem)
        )
        Builtins.y2error("DA: %1", old_addr)
        @forwarders = Builtins.filter(@forwarders) { |f| f != old_addr }
      elsif ret == "forwarder_policy"
        handlePolicy(
          Convert.to_symbol(UI.QueryWidget(Id("forwarder_policy"), :Value))
        )
      end

      RedrawForwardersListWidget()
      nil
    end

    # Dialog Expert Settings - Basic Options
    # @return [Yast::Term] for Get_ExpertDialog()
    def ExpertBasicOptionsDialog
      dialog =
        # `Top (
        VBox(
          VSquash(
            # Frame label for Basic-Options
            Frame(
              _("Add or Change Option"),
              VBox(
                HBox(
                  HWeight(
                    9,
                    Bottom(
                      VBox(
                        HBox(
                          HWeight(
                            3,
                            # Combobox for choosing the basic-option
                            ComboBox(
                              Id("basic_option_selection"),
                              Opt(:editable),
                              _("O&ption"),
                              @global_options_add_items
                            )
                          ),
                          HWeight(
                            5,
                            # Textentry for setting the basic-option value
                            InputField(
                              Id("basic_option_value"),
                              Opt(:hstretch),
                              _("&Value"),
                              ""
                            )
                          )
                        )
                      )
                    )
                  ),
                  HWeight(
                    2,
                    Bottom(
                      VBox(
                        VSquash(
                          PushButton(
                            Id("add_basic_option"),
                            Opt(:hstretch),
                            Label.AddButton
                          )
                        ),
                        # Pushbutton for changing the basic-option
                        VSquash(
                          PushButton(
                            Id("change_basic_option"),
                            Opt(:hstretch),
                            _("C&hange")
                          )
                        )
                      )
                    )
                  )
                ),
                VSpacing(0.5)
              )
            )
          ),
          VSpacing(0.5),
          VBox(
            # Table label for basic-options listing
            Left(Label(_("Current Options"))),
            HBox(
              HWeight(
                9,
                Table(
                  Id("basic_options_table"),
                  Opt(:notify, :immediate, :vstretch),
                  Header(
                    # Table header item - basic-options listing
                    _("Option"),
                    # Table header item - basic-options listing
                    _("Value")
                  ),
                  []
                )
              ),
              HWeight(
                2,
                VBox(
                  VSquash(
                    PushButton(
                      Id("delete_basic_option"),
                      Opt(:hstretch),
                      Label.DeleteButton
                    )
                  ),
                  VStretch()
                )
              )
            )
          )
        )
      #);
      deep_copy(dialog)
    end

    def ReinitializeOptionAddWidgets
      current_opt = Convert.to_integer(
        UI.QueryWidget(Id("basic_options_table"), :CurrentItem)
      )
      o = Ops.get(@options, current_opt, {})
      if o == {}
        UI.ChangeWidget(Id("basic_option_value"), :Value, "")
      else
        UI.ChangeWidget(
          Id("basic_option_value"),
          :Value,
          Ops.get_string(o, "value", "")
        )
        UI.ChangeWidget(
          Id("basic_option_selection"),
          :Value,
          Ops.get_string(o, "key", "")
        )
      end

      nil
    end

    def RedrawOptionsTableWidget
      current = Convert.to_integer(
        UI.QueryWidget(Id("basic_options_table"), :CurrentItem)
      )
      index = -1
      UI.ChangeWidget(
        Id("basic_options_table"),
        :Items,
        Builtins.maplist(@options) do |o|
          index = Ops.add(index, 1)
          Item(Id(index), Ops.get_string(o, "key", ""), Ops.get(o, "value"))
        end
      )
      if current != nil && Ops.less_than(current, Builtins.size(@options))
        UI.ChangeWidget(Id("basic_options_table"), :CurrentItem, current)
      end
      UI.ChangeWidget(
        Id("delete_basic_option"),
        :Enabled,
        Ops.greater_than(Builtins.size(@options), 0)
      )
      ReinitializeOptionAddWidgets()

      nil
    end

    # Initialize the tab of the dialog
    def InitExpertBasicOptionsPage(key)
      SetDNSSErverIcon()
      @options = DnsServer.GetGlobalOptions
      @current_option_index = 0
      RedrawOptionsTableWidget()

      nil
    end

    # Store settings of a tab of a dialog
    def StoreExpertBasicOptionsPage(key, event)
      event = deep_copy(event)
      DnsServer.SetGlobalOptions(@options)

      nil
    end

    # Return if the option must be unique in configuration or not
    def IsUniqueOption(option)
      # global_options_unique_items is a list of known unique records
      Builtins.contains(@global_options_unique_items, option)
    end

    # Returns if the option was set yet
    def OptionIsSetYet(option)
      if Ops.greater_than(
          Builtins.size(
            # filters all records whith key = option
            Builtins.filter(@options) do |option_record|
              Ops.get(option_record, "key") == option
            end # options are list, size returns count of records
          ),
          0
        )
        return true
      end
      false
    end

    # Returns if the option must be "yes" or "no"
    def OptionsIsYesNoType(option)
      Builtins.contains(@global_options_yesno_items, option)
    end

    # Returns if the option must be a number
    def OptionsIsNumberType(option)
      Builtins.contains(@global_options_number_items, option)
    end

    def CheckOptionValue(option, value)
      # any value should be set
      if value == nil || value == ""
        if !Popup.YesNo(
            # TRANSLATORS: Popup question
            _("Really set this\noption without any value?\n")
          )
          return false
        end 
        # it is a YES or NO type
      elsif OptionsIsYesNoType(option)
        # it has not a yes/no value
        if !Builtins.regexpmatch(value, "^ *[yY][eE][sS] *$") &&
            !Builtins.regexpmatch(value, "^ *[nN][oO] *$")
          if !Popup.ContinueCancel(
              Builtins.sformat(
                # TRANSLATORS: Popup question. Please, do not translate 'yes' and 'no' strings. %1 is a name of the option, %2 is the value of the option.
                _(
                  "Option %1 can only have a yes or no value set.\nReally set it to %2?\n"
                ),
                option,
                value
              )
            )
            return false
          end
        end 
        # it must be a number
      elsif OptionsIsNumberType(option)
        # if has not a number value
        if !Builtins.regexpmatch(value, "^ *[0123456789] *$")
          if !Popup.ContinueCancel(
              Builtins.sformat(
                # TRANSLATORS: Popup question. %1 is a name of the option, %2 is the value of the option.
                _("Option %1 can only be a number.\nReally set it to %2?\n"),
                option,
                value
              )
            )
            return false
          end
        end
      elsif !DnsRoutines.CheckQuoting(value)
        if !Popup.ContinueCancel(
            Builtins.sformat(
              # TRANSLATORS: Popup question. %1 is the value of the option.
              _(
                "Quotes are not used correctly in this option.\nReally set it to %1?\n"
              ),
              value
            )
          )
          return false
        end
      elsif !DnsRoutines.CheckBrackets(value)
        if !Popup.ContinueCancel(
            Builtins.sformat(
              # TRANSLATORS: Popup question. %1 is the value of the option.
              _(
                "Brackets are not used correctly in this option.\nReally set it to %1?\n"
              ),
              value
            )
          )
          return false
        end
      end

      true
    end

    # Handle events in a tab of a dialog
    def HandleExpertBasicOptionsPage(key, event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")
      index = Convert.to_integer(
        UI.QueryWidget(Id("basic_options_table"), :CurrentItem)
      )
      current_key = Convert.to_string(
        UI.QueryWidget(Id("basic_option_selection"), :Value)
      )
      current_value = Convert.to_string(
        UI.QueryWidget(Id("basic_option_value"), :Value)
      )
      if ret == "basic_options_table"
        ReinitializeOptionAddWidgets()
      elsif ret == "delete_basic_option"
        return nil if !Confirm.DeleteSelected

        Ops.set(@options, index, nil)
        @options = Builtins.filter(@options) { |o| o != nil }
        RedrawOptionsTableWidget()
        return nil
      elsif ret == "add_basic_option"
        # testing options for right values
        return nil if !CheckOptionValue(current_key, current_value)

        # option is unique and was set yet
        if IsUniqueOption(current_key) && OptionIsSetYet(current_key)
          if !Popup.ContinueCancel(
              Builtins.sformat(
                # Popup question, %1 is the name of the option
                _(
                  "Option %1 should be set only once.\nReally add another one?\n"
                ),
                current_key
              )
            )
            return nil
          end
          Builtins.y2warning("Added unique option '%1' more times", current_key)
        end

        @options = Builtins.add(
          @options,
          { "key" => current_key, "value" => current_value }
        )
        RedrawOptionsTableWidget()
        return nil
      elsif ret == "change_basic_option"
        # testing options for right values
        return nil if !CheckOptionValue(current_key, current_value)

        Ops.set(@options, [index, "key"], current_key)
        Ops.set(@options, [index, "value"], current_value)
        RedrawOptionsTableWidget()
        return nil
      end

      nil
    end


    # Dialog Expert Settings - Logging
    # @return [Yast::Term] for Get_ExpertDialog()
    def Expert_Logging_Dialog
      dialog = Top(
        HBox(
          HWeight(
            5,
            # Table header - logging options
            Frame(
              _("Log Type"),
              Top(
                VBox(
                  VSquash(
                    RadioButtonGroup(
                      Id("log_type"),
                      VBox(
                        # Radiobutton - log type
                        Left(
                          RadioButton(
                            Id("log_type_system"),
                            Opt(:notify),
                            _("&System Log"),
                            true
                          )
                        ),
                        # Radiobutton - log type
                        Left(
                          RadioButton(
                            Id("log_type_file"),
                            Opt(:notify),
                            _("&File")
                          )
                        )
                      )
                    )
                  ),
                  VSpacing(0.5),
                  HBox(
                    HSpacing(3),
                    VBox(
                      VWeight(
                        25,
                        HBox(
                          InputField(
                            Id("logfile_path"),
                            Opt(:hstretch),
                            Label.FileName
                          ),
                          VBox(
                            VStretch(),
                            # Pushbutton - browse filesystem for logfile
                            PushButton(
                              Id("browse_logfile_path"),
                              Label.BrowseButton
                            )
                          )
                        )
                      ),
                      # IntField - max. log size
                      VWeight(
                        25,
                        IntField(
                          Id("max_size"),
                          _("Maximum &Size (MB)"),
                          0,
                          4096,
                          0
                        )
                      ),
                      # IntField - max. log age
                      VWeight(
                        25,
                        IntField(
                          Id("max_versions"),
                          _("Maximum &Versions"),
                          0,
                          100,
                          0
                        )
                      ),
                      VStretch()
                    )
                  )
                )
              )
            )
          ),
          HSpacing(1),
          HWeight(
            3,
            # Frame label - additional-logging
            Frame(
              _("Additional Logging"),
              Top(
                VBox(
                  # Checkbox - additional-logging
                  Left(
                    CheckBox(Id("l_named_queries"), _("Log All DNS &Queries"))
                  ),
                  # Checkbox - additional-logging
                  Left(CheckBox(Id("l_zone_updates"), _("Log Zone &Updates"))),
                  # Checkbox - additional-logging
                  Left(
                    CheckBox(Id("l_zone_transfers"), _("Log Zone &Transfers"))
                  ),
                  VStretch()
                )
              )
            )
          )
        )
      )
      deep_copy(dialog)
    end

    # Initialize the tab of the dialog
    def InitExpertLoggingPage(key)
      SetDNSSErverIcon()
      channel = DnsServerAPI.GetLoggingChannel
      if Ops.get(channel, "destination") == "file"
        UI.ChangeWidget(Id("log_type"), :CurrentButton, "log_type_file")
        UI.ChangeWidget(
          Id("max_versions"),
          :Value,
          Builtins.tointeger(Ops.get(channel, "versions", "0"))
        )
        UI.ChangeWidget(
          Id("logfile_path"),
          :Value,
          Ops.get(channel, "filename", "")
        )

        sz = 0
        su = ""
        # if size is defined and
        if Ops.get(channel, "size") != nil &&
            Ops.greater_than(
              Builtins.tointeger(Ops.get(channel, "size", "0")),
              0
            )
          sz = Builtins.tointeger(
            Builtins.regexpsub(
              Ops.get(channel, "size", ""),
              "([0123456789]+)",
              "\\1"
            )
          )
          # size is only number, no unit assigned
          if Ops.get(channel, "size") != Builtins.tostring(sz)
            su = Builtins.tolower(
              Builtins.regexpsub(
                Ops.get(channel, "size", ""),
                "[0123456789]+([kKmMgG])",
                "\\1"
              )
            )
          end
        end
        if su != nil
          # no unit = in Bytes
          if su == ""
            sz = Builtins.tointeger(
              Ops.add(
                Convert.convert(
                  Ops.divide(Ops.divide(sz, 1024), 1024),
                  :from => "integer",
                  :to   => "float"
                ),
                0.5
              )
            )
          elsif su == "k"
            sz = Builtins.tointeger(
              Ops.add(
                Convert.convert(
                  Ops.divide(sz, 1024),
                  :from => "integer",
                  :to   => "float"
                ),
                0.5
              )
            )
          # else if (su == "m") {} # M is the default unit
          elsif su == "g"
            sz = Ops.multiply(sz, 1024)
          end
        end
        UI.ChangeWidget(Id("max_size"), :Value, sz) if sz != nil
      else
        UI.ChangeWidget(Id("log_type"), :CurrentButton, "log_type_system")
      end

      categories = DnsServerAPI.GetLoggingCategories
      if Builtins.contains(categories, "queries")
        UI.ChangeWidget(Id("l_named_queries"), :Value, true)
      end
      if Builtins.contains(categories, "xfer-in")
        UI.ChangeWidget(Id("l_zone_updates"), :Value, true)
      end
      if Builtins.contains(categories, "xfer-out")
        UI.ChangeWidget(Id("l_zone_transfers"), :Value, true)
      end

      HandleExpertLoggingPage(key, { "ID" => "log_type_system" })

      nil
    end

    # Store settings of a tab of a dialog
    def StoreExpertLoggingPage(key, event)
      event = deep_copy(event)
      used_categories = []
      if Convert.to_boolean(UI.QueryWidget(Id("l_named_queries"), :Value))
        used_categories = Builtins.add(used_categories, "queries")
      end
      if Convert.to_boolean(UI.QueryWidget(Id("l_zone_updates"), :Value))
        used_categories = Builtins.add(used_categories, "xfer-in")
      end
      if Convert.to_boolean(UI.QueryWidget(Id("l_zone_transfers"), :Value))
        used_categories = Builtins.add(used_categories, "xfer-out")
      end
      DnsServerAPI.SetLoggingCategories(used_categories)

      use_file = UI.QueryWidget(Id("log_type"), :CurrentButton) == "log_type_file"
      if use_file
        DnsServerAPI.SetLoggingChannel(
          {
            "destination" => "file",
            "filename"    => Convert.to_string(
              UI.QueryWidget(Id("logfile_path"), :Value)
            ),
            "size"        => Ops.add(
              Builtins.tostring(UI.QueryWidget(Id("max_size"), :Value)),
              "M"
            ),
            "versions"    => Builtins.tostring(
              UI.QueryWidget(Id("max_versions"), :Value)
            )
          }
        )
      else
        DnsServerAPI.SetLoggingChannel({ "destination" => "syslog" })
      end

      nil
    end
    def HandleExpertLoggingPage(key, event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")
      if ret == "log_type_system" || ret == "log_type_file"
        en = UI.QueryWidget(Id("log_type"), :CurrentButton) == "log_type_file"
        Builtins.foreach(
          ["logfile_path", "browse_logfile_path", "max_size", "max_versions"]
        ) { |w| UI.ChangeWidget(Id(w), :Enabled, en) }
      elsif ret == "browse_logfile_path"
        fn = Convert.to_string(UI.QueryWidget(Id("logfile_path"), :Value))
        fn = UI.AskForSaveFileName(
          fn,
          "",
          # popup headline
          _("Select File for Log")
        )
        UI.ChangeWidget(Id("logfile_path"), :Value, fn) if fn != nil
      end
      nil
    end


    # Dialog Expert Settings - ACLs
    # @return [Yast::Term] for Get_ExpertDialog()
    def Expert_ACLs_Dialog
      dialog =
        #`Top (
        VBox(
          VSquash(
            # Frame label - adding ACL-optiopn
            Frame(
              _("Option Setup"),
              VBox(
                HBox(
                  HWeight(
                    9,
                    VBox(
                      HBox(
                        HWeight(
                          3,
                          # Textentry - adding ACL-optiopn - name
                          InputField(
                            Id("new_acl_name"),
                            Opt(:hstretch),
                            _("&Name")
                          )
                        ),
                        HWeight(
                          5,
                          # Textentry - adding ACL-optiopn - value
                          InputField(
                            Id("new_acl_value"),
                            Opt(:hstretch),
                            _("&Value")
                          )
                        )
                      )
                    )
                  ),
                  HWeight(
                    2,
                    VBox(
                      VStretch(),
                      VSquash(
                        PushButton(
                          Id("add_acl"),
                          Opt(:hstretch),
                          Label.AddButton
                        )
                      )
                    )
                  )
                ),
                VSpacing(0.5)
              )
            )
          ),
          VSpacing(1),
          VBox(
            # Table header - ACL-options listing
            Left(Label(_("Current ACL List"))),
            HBox(
              HWeight(
                9,
                Table(
                  Id("acl_listing_table"),
                  Header(
                    # Table header item - ACL-options
                    _("ACL"),
                    # Table header item - ACL-options
                    _("Value")
                  ),
                  [
                    # FIXME: real ACL data (list)
                    Item(Id(1), "can_acfr", nil),
                    Item(Id(2), "can_query", nil)
                  ]
                )
              ),
              HWeight(
                2,
                VBox(
                  VSquash(
                    PushButton(
                      Id("delete_acl"),
                      Opt(:hstretch),
                      Label.DeleteButton
                    )
                  ),
                  VStretch()
                )
              )
            )
          )
        )
      #);
      deep_copy(dialog)
    end

    def RedrawAclPage
      index = -1
      items = Builtins.maplist(@acl) do |a|
        index = Ops.add(index, 1)
        while Builtins.substring(a, 0, 1) == " " ||
            Builtins.substring(a, 0, 1) == "\t"
          a = Builtins.substring(a, 1)
        end
        s = Builtins.splitstring(a, " \t")
        type = Ops.get(s, 0, "")
        Ops.set(s, 0, "")
        a = Builtins.mergestring(s, " ")
        while Builtins.substring(a, 0, 1) == " " ||
            Builtins.substring(a, 0, 1) == "\t"
          a = Builtins.substring(a, 1)
        end
        Item(Id(index), type, a)
      end
      UI.ChangeWidget(Id("acl_listing_table"), :Items, items)

      nil
    end

    # Initialize the tab of the dialog
    def InitExpertAclPage(key)
      SetDNSSErverIcon()
      @acl = DnsServer.GetAcl
      UI.ChangeWidget(
        Id("new_acl_name"),
        :ValidChars,
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
      )
      RedrawAclPage()

      nil
    end

    # Store settings of a tab of a dialog
    def StoreExpertAclPage(key, event)
      event = deep_copy(event)
      DnsServer.SetAcl(@acl)

      nil
    end

    # Testing for acls duplicity
    # @return true if the name is duplicate
    def IsAclDefined(new_name, acls)
      acls = deep_copy(acls)
      return true if Builtins.foreach(acls) do |acl|
        splitted = Builtins.splitstring(acl, " \t")
        next true if new_name == Ops.get(splitted, 0, "")
      end == true
      false
    end

    # Returns zones where acl is used
    def GetZonesWithAclUsed(acl_name)
      zones_touched = []

      zones = DnsServer.FetchZones
      Builtins.foreach(zones) do |zone|
        Builtins.foreach(Ops.get_list(zone, "options", [])) do |option|
          if Ops.get_string(option, "key", "") == "allow-transfer"
            Builtins.foreach(
              Builtins.splitstring(Ops.get_string(option, "value", ""), "; {}")
            ) do |used_acl|
              if used_acl == acl_name
                zones_touched = Builtins.add(
                  zones_touched,
                  Ops.get_string(zone, "zone", "")
                )
              end
            end
          end
        end
      end

      Builtins.toset(zones_touched)
    end

    # Really remove used ACL? (dialog)
    def ReallyRemoveACL(acl_name)
      zones_where_acl_used = GetZonesWithAclUsed(acl_name)

      if Ops.greater_than(Builtins.size(zones_where_acl_used), 0)
        return Popup.ContinueCancel(
          Builtins.sformat(
            # A popup question, %1 is number of zones
            _("This ACL is used by %1 zones.\nReally remove it?\n"),
            Builtins.size(zones_where_acl_used)
          )
        )
      else
        return true
      end
    end

    # Handle events in a tab of a dialog
    def HandleExpertAclPage(key, event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")
      index = Convert.to_integer(
        UI.QueryWidget(Id("acl_listing_table"), :CurrentItem)
      )
      if ret == "delete_acl"
        a = Ops.get(@acl, index, "")
        while Builtins.substring(a, 0, 1) == " " ||
            Builtins.substring(a, 0, 1) == "\t"
          a = Builtins.substring(a, 1)
        end
        s = Builtins.splitstring(a, " \t")
        a = Ops.get(s, 0, "")

        # Testing if ACL is used
        return nil if !ReallyRemoveACL(a)

        zones = DnsServer.FetchZones
        zones = Builtins.maplist(zones) do |z|
          options = Ops.get_list(z, "options", [])
          options = Builtins.maplist(options) do |o|
            if Ops.get_string(o, "key", "") == "allow-transfer"
              keys = Builtins.splitstring(
                Ops.get_string(o, "value", ""),
                "; {}"
              )
              keys = Builtins.filter(keys) { |k| k != "" }
              keys = Builtins.filter(keys) { |k| k != a }
              Ops.set(
                o,
                "value",
                Builtins.sformat("{ %1; }", Builtins.mergestring(keys, "; "))
              )
            end
            deep_copy(o)
          end
          Ops.set(z, "options", options)
          deep_copy(z)
        end
        DnsServer.StoreZones(zones)

        Ops.set(@acl, index, nil)
        @acl = Builtins.filter(@acl) { |a2| a2 != nil }
        RedrawAclPage()
      elsif ret == "add_acl"
        n = Convert.to_string(UI.QueryWidget(Id("new_acl_name"), :Value))
        v = Convert.to_string(UI.QueryWidget(Id("new_acl_value"), :Value))
        if n != nil && Builtins.regexpmatch(n, "^[ \t]*[a-z0-9_-]+[ \t]*$") &&
            v != nil &&
            Builtins.regexpmatch(v, "[^ \t\\{\\};]")
          # strip leading & trailing spaces
          # as well as a trailing ';' char
          if Builtins.regexpmatch(v, "^[ \t]+.*$")
            v = Builtins.regexpsub(v, "^[ \t]+(.*)$", "\\1")
          end
          if Builtins.regexpmatch(v, "^.*[ \t]+$")
            v = Builtins.regexpsub(v, "^(.*)[ \t]+$", "\\1")
          end
          if Builtins.regexpmatch(v, "^.*[ \t]*;$")
            v = Builtins.regexpsub(v, "^(.*)[ \t]*;$", "\\1")
          end

          # should be a block begining with a '{'
          v = Ops.add("{ ", v) if !Builtins.regexpmatch(v, "^\\{")

          # make sure, there is a block end '}'
          # note: ';' after '}' is added later
          if !Builtins.regexpmatch(v, "\\}$")
            # terminate list with ';' if needed
            v = Ops.add(v, ";") if !Builtins.regexpmatch(v, ";$")
            v = Ops.add(v, " }")
          end
          # testing for ACL duplicity
          if IsAclDefined(n, @acl)
            UI.SetFocus(Id("new_acl_name"))
            # An error popup message
            Popup.Message(_("The specified ACL entry already exists."))
          else
            @acl = Builtins.add(@acl, Builtins.sformat("%1 %2", n, v))
            RedrawAclPage()
          end
        end
      end
      nil
    end

    # Dialog Expert Settings - ZonesZones
    # @return [Yast::Term] for Get_ExpertDialog()
    def ExpertZonesDialog
      dialog = VBox(
        VSquash(
          # frame label
          Frame(
            _("Add New Zone "),
            HBox(
              HWeight(
                9,
                # Frame label - DNS adding zone
                VBox(
                  #`VSpacing ( 0.5 ),
                  HBox(
                    # Textentry - DNS adding zone - Name
                    InputField(
                      Id("new_zone_name"),
                      Opt(:hstretch),
                      _("Name"),
                      "example.com"
                    ),
                    # Combobox - DNS adding zone - Type
                    ComboBox(
                      Id("new_zone_type"),
                      _("Type"),
                      [
                        # Combobox - DNS adding zone - Type Master
                        Item(Id("master"), _("Master")),
                        # Combobox - DNS adding zone - Type Slave
                        Item(Id("slave"), _("Slave")),
                        # Combobox - DNS adding zone - Type Slave
                        Item(Id("forward"), _("Forward"))
                      ]
                    )
                  ),
                  VSpacing(0.5)
                )
              ),
              HWeight(
                2,
                VBox(
                  VSpacing(1),
                  #`VSquash (
                  PushButton(Id("add_zone"), Opt(:hstretch), Label.AddButton),
                  #),
                  VSpacing(0.5)
                )
              )
            )
          )
        ),
        VSpacing(1),
        VBox(
          # Table header - DNS listing zones
          Left(Label(_("Configured DNS Zones"))),
          HBox(
            VStretch(Opt(:vstretch)),
            HWeight(
              9,
              Table(
                Id("zones_list_table"),
                Opt(:vstretch),
                Header(
                  # Table header item - DNS listing zones
                  _("Zone"),
                  # Table header item - DNS listing zones
                  _("Type")
                ),
                []
              )
            ),
            HWeight(
              2,
              VBox(
                VSquash(
                  PushButton(
                    Id("delete_zone"),
                    Opt(:hstretch),
                    Label.DeleteButton
                  )
                ),
                VSquash(
                  PushButton(Id("edit_zone"), Opt(:hstretch), Label.EditButton)
                ),
                VStretch()
              )
            )
          )
        )
      )

      deep_copy(dialog)
    end

    def RedrawZonesListWidget
      # Translating of all zone names at once
      encoded_zone_names = Builtins.maplist(@zones) do |z|
        Ops.get_string(z, "zone", "")
      end
      decoded_zone_names = Punycode.DocodeDomainNames(encoded_zone_names)
      index = -1
      # Creating map $[encoded:decoded]
      enc_to_dec = Builtins.listmap(encoded_zone_names) do |enc_zone|
        index = Ops.add(index, 1)
        { enc_zone => Ops.get(decoded_zone_names, index, "") }
      end

      index = -1
      items = Builtins.maplist(@zones) do |z|
        index = Ops.add(index, 1)
        zone_name = Ops.get_string(z, "zone", "")
        # filtering out default zones
        next Item() if DnsServerHelperFunctions.IsInternalZone(zone_name)
        type_trans = ""
        case Ops.get_string(z, "type", "master")
          when "master"
            # TRANSLATORS: Table item - Server type
            type_trans = _("Master")
          when "slave"
            # TRANSLATORS: Table item - Server type
            type_trans = _("Slave")
          when "stub"
            # TRANSLATORS: Table item - Server type
            type_trans = _("Slave")
          when "forward"
            # TRANSLATORS: Table item - Server type
            type_trans = _("Forward")
          else
            Builtins.y2warning("Unknown zone type %1", type_trans)
        end
        Item(Id(index), Ops.get(enc_to_dec, zone_name, zone_name), type_trans)
      end

      # Filtering out empty items
      items = Builtins.filter(items) { |i| i != Item() }

      # Sorting by the zone name (might have different sorting than UI)
      items = Builtins.sort(items) do |x, y|
        Ops.less_than(Ops.get_string(x, 1, ""), Ops.get_string(y, 1, ""))
      end

      UI.ChangeWidget(Id("zones_list_table"), :Items, items)
      UI.SetFocus(Id("zones_list_table"))
      UI.ChangeWidget(
        Id("delete_zone"),
        :Enabled,
        Ops.greater_than(Builtins.size(items), 0)
      )
      UI.ChangeWidget(
        Id("edit_zone"),
        :Enabled,
        Ops.greater_than(Builtins.size(items), 0)
      )

      nil
    end

    # Initialize the tab of the dialog
    def InitExpertZonesPage(key)
      SetDNSSErverIcon()
      @zones = DnsServer.FetchZones
      RedrawZonesListWidget()

      nil
    end

    # Store settings of a tab of a dialog
    def StoreExpertZonesPage(key, event)
      event = deep_copy(event)
      nil
    end

    def TransformToReverseIPv6ZoneName(zone_name)
      if !Builtins.regexpmatch(zone_name, "^[:0-9A-Fa-f]+/[0-9]+$")
        Builtins.y2error("No a required format: %1", zone_name)
        return zone_name
      end

      zone_translated = Builtins.regexpsub(
        zone_name,
        "^([:0-9A-Fa-f]+)/[0-9]+$",
        "\\1"
      )
      zone_bits = Builtins.tointeger(
        Builtins.regexpsub(zone_name, "^[:0-9A-Fa-f]+/([0-9]+)$", "\\1")
      )

      zone_translated = DnsServerAPI.GetReverseIPforIPv6(zone_translated)
      zone_bits = 128 if Ops.greater_than(zone_bits, 128)
      zone_bits = Ops.divide(zone_bits, 4)

      zone_translated = Builtins.substring(
        zone_translated,
        Ops.multiply(2, zone_bits)
      )

      Builtins.y2milestone(
        "Guessing zone: '%1' from '%2'",
        zone_translated,
        zone_name
      )

      zone_translated
    end

    # Handle events in a tab of a dialog
    def HandleExpertZonesPage(key, event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")
      index = Convert.to_integer(
        UI.QueryWidget(Id("zones_list_table"), :CurrentItem)
      )

      if ret == "delete_zone"
        # Confirm deleting zone
        return nil if !Confirm.DeleteSelected

        Ops.set(@zones, index, nil)
        @zones = Builtins.filter(@zones) { |z| z != nil }
        DnsServer.StoreZones(@zones)
        RedrawZonesListWidget()
        return nil
      elsif ret == "add_zone"
        zone_name = Convert.to_string(
          UI.QueryWidget(Id("new_zone_name"), :Value)
        )
        zone_type = Convert.to_string(
          UI.QueryWidget(Id("new_zone_type"), :Value)
        )



        # IPv6 zone name in forward format
        # e.g., "3ffe:ffff::210:a4ff:fe01:1/48"
        if Builtins.regexpmatch(zone_name, "^[:0-9A-Fa-f]+/[0-9]+$")
          zone_name = TransformToReverseIPv6ZoneName(zone_name) 
          # e.g., "3ffe:ffff::210:a4ff:fe01:1" without bits
        elsif IP.Check6(zone_name)
          zone_name = TransformToReverseIPv6ZoneName(Ops.add(zone_name, "/64"))
        end

        # Do not add the final dot to the zone name
        if Builtins.regexpmatch(zone_name, "\\.+$")
          zone_name = Builtins.regexpsub(zone_name, "(.*)\\.+$", "\\1")
        end

        encoded_zone_name = Punycode.EncodeDomainName(zone_name)

        # zone validation
        if Hostname.CheckDomain(encoded_zone_name) != true
          UI.SetFocus(Id("new_zone_name"))
          # FIXME: another message!
          Popup.Error(Hostname.ValidDomain)
          return nil
        end

        zones_same = Builtins.filter(@zones) do |z2|
          Ops.get_string(z2, "zone", "") == encoded_zone_name
        end
        if Builtins.size(zones_same) != 0
          UI.SetFocus(Id("new_zone_name"))
          # error report
          Popup.Error(
            _("A zone with the specified name is already configured.")
          )
          return nil
        end

        DnsServer.StoreZones(@zones)
        DnsServer.SelectZone(-1)
        z = DnsServer.FetchCurrentZone
        z = Convert.convert(
          Builtins.union(
            z,
            { "zone" => encoded_zone_name, "type" => zone_type }
          ),
          :from => "map",
          :to   => "map <string, any>"
        )

        Builtins.y2milestone("Created zone: %1 (%2)", z, zone_name)
        DnsServer.StoreCurrentZone(z)
        DnsServer.StoreZone
        @zones = DnsServer.FetchZones
        RedrawZonesListWidget()

        # fixing bug #45950, slave zone _MUST_ have master server
        if zone_type == "slave"
          DnsServer.SelectZone(Ops.subtract(Builtins.size(@zones), 1))
          @current_zone = DnsServer.FetchCurrentZone
          return :edit_zone
        end
      elsif ret == "edit_zone"
        # next time, the initial screen will be "zones"
        @initial_screen = "zones"
        DnsServer.SelectZone(index)
        @current_zone = DnsServer.FetchCurrentZone
        return :edit_zone
      end

      nil
    end

    # Write settings dialog
    # @return `abort if aborted and `next otherwise
    def WriteDialog
      Wizard.RestoreHelp(Ops.get_string(@HELPS, "write", ""))
      ret = DnsServer.Write
      if ret
        service.reload if service.running? && status_widget.reload_flag?
        :next
      else
        if Popup.YesNo(_("Saving the configuration failed. Change the settings?"))
          :back
        else
          :abort
        end
      end
    end

    # Writes settings and restores the dialog without exiting
    def SaveAndRestart
      Wizard.CreateDialog
      Wizard.RestoreHelp(Ops.get_string(@HELPS, "write", ""))
      ret = DnsServer.Write
      if ret
        service.reload if service.running? && status_widget.reload_flag?
      else
        Report.Error(_("Saving the configuration failed"))
      end
      Builtins.sleep(1000)
      UI.CloseDialog

      nil
    end

    # Ask for exit without saving
    # @return event that should be handled, nil if user canceled the exit
    def confirmAbort
      Popup.YesNo(
        # Yes-No popup
        _(
          "All changes will be lost.\nReally leave the DNS server configuration without saving?"
        )
      )
    end

    # Check whether settings were changed and if yes, ask for exit
    # without saving
    # @return event that should be handled, nil if user canceled the exit
    def confirmAbortIfChanged
      return true if !DnsServer.WasModified
      confirmAbort
    end

    # Dialog Expert Settings
    # @return [Symbol] for the wizard sequencer
    def runExpertDialog
      expert_dialogs = [
        "start_up",
        "forwarders",
        "basic_options",
        "logging",
        "acls",
        "keys",
        "zones"
      ]
      normal_dialog = ["start_up", "forwarders", "logging", "zones"]

      DialogTree.ShowAndRun(
        {
          "ids_order"      => DnsServer.ExpertUI ? expert_dialogs : normal_dialog,
          "initial_screen" => @initial_screen,
          "screens"        => tabs,
          "widget_descr"   => new_widgets,
          "back_button"    => "",
          "abort_button"   => Label.CancelButton,
          "next_button"    => Label.OKButton,
          "functions"      => @functions
        }
      )
    end

    # Returns a hash describing the UI tabs
    def tabs
      @tabs ||= {
        "start_up"      => {
          # FIXME: new startup
          "contents"        => VBox(
            status_widget.widget,
            VSpacing(),
            "firewall",
            VStretch(),
            Right(
              PushButton(Id("apply"), _("Apply Changes"))
            )
          ),
          # Dialog Label - DNS - expert settings
          "caption"         => Ops.add(
            Ops.add(@dns_server_label, ": "),
            _("Start-Up")
          ),
          # Tree Menu Item - DNS - expert settings
          "tree_item_label" => _(
            "Start-Up"
          ),
          # FIXME: new startup
          "widget_names"    => DnsServer.ExpertUI ?
            # expert mode
            ["start_up", "firewall"] :
            # simple mode
            ["start_up", "firewall", "set_icon"]
        },
        "forwarders"    => {
          "contents"        => ExpertForwardersDialog(),
          # Dialog Label - DNS - expert settings
          "caption"         => Ops.add(
            Ops.add(@dns_server_label, ": "),
            _("Forwarders")
          ),
          # Tree Menu Item - DNS - expert settings
          "tree_item_label" => _(
            "Forwarders"
          ),
          "widget_names"    => ["forwarders"]
        },
        "basic_options" => {
          "contents"        => ExpertBasicOptionsDialog(),
          # Dialog Label - DNS - expert settings
          "caption"         => Ops.add(
            Ops.add(@dns_server_label, ": "),
            _("Basic Options")
          ),
          # Tree Menu Item - DNS - expert settings
          "tree_item_label" => _(
            "Basic Options"
          ),
          "widget_names"    => ["basic_options"]
        },
        "logging"       => {
          "contents"        => Expert_Logging_Dialog(),
          # Dialog Label - DNS - expert settings
          "caption"         => Ops.add(
            Ops.add(@dns_server_label, ": "),
            _("Logging")
          ),
          "tree_item_label" => _("Logging"),
          # Tree Menu Item - DNS - expert settings
          "widget_names"    => [
            "logging"
          ]
        },
        "acls"          => {
          "contents"        => Expert_ACLs_Dialog(),
          # Dialog Label - DNS - expert settings
          "caption"         => Ops.add(
            Ops.add(@dns_server_label, ": "),
            _("ACLs")
          ),
          # Tree Menu Item - DNS - expert settings
          "tree_item_label" => _(
            "ACLs"
          ),
          "widget_names"    => ["acls"]
        },
        "keys"          => {
          "contents"        => HBox(
            HSpacing(2),
            VBox(VSpacing(1), "tsig_keys", VSpacing(1)),
            HSpacing(2)
          ),
          # Dialog Label - DNS - expert settings
          "caption"         => Ops.add(
            Ops.add(@dns_server_label, ": "),
            _("TSIG Keys")
          ),
          # Tree Menu Item - DNS - expert settings
          "tree_item_label" => _(
            "TSIG Keys"
          ),
          "widget_names"    => ["tsig_keys"],
          "widget_descr"    => new_widgets
        },
        "zones"         => {
          "contents"        => VBox(
            "use_ldap",
            VSpacing(),
            ExpertZonesDialog()
          ),
          # Dialog Label - DNS - expert settings
          "caption"         => Ops.add(
            Ops.add(@dns_server_label, ": "),
            _("DNS Zones")
          ),
          # Tree Menu Item - DNS - expert settings
          "tree_item_label" => _(
            "DNS Zones"
          ),
          "widget_names"    => ["use_ldap", "zones"]
        }
      }
    end

    # Returns a hash describing the UI widgets
    def new_widgets
      @new_widgets ||= {
        "start_up"    => {
          "widget"        => :custom,
          "custom_widget" => VBox(),
          "init"          => fun_ref(
            method(:InitStartUp),
            "void (string)"
          ),
          "handle"        => fun_ref(
            method(:HandleStartUp),
            "symbol (string, map)"
          ),
          "help"          => status_widget.help
        },
        "firewall"      => CWMFirewallInterfaces.CreateOpenFirewallWidget(
          { "services" => ["dns"], "display_details" => true }
        ),
        "use_ldap"      => CWMServiceStart.CreateLdapWidget(
          {
            "get_use_ldap"      => fun_ref(
              DnsServer.method(:GetUseLdap),
              "boolean ()"
            ),
            "set_use_ldap"      => fun_ref(
              DnsServer.method(:SetUseLdap),
              "boolean (boolean)"
            ),
            # TRANSLATORS: checkbox label, turning LDAP support on or off
            "use_ldap_checkbox" => _(
              "&LDAP Support Active"
            ),
            "help"              => CWMServiceStart.EnableLdapHelp
          }
        ),
        "forwarders"    => {
          "widget"        => :custom,
          "custom_widget" => VBox(),
          "init"          => fun_ref(
            method(:InitExpertForwardersPage),
            "void (string)"
          ),
          "handle"        => fun_ref(
            method(:HandleExpertForwardersPage),
            "symbol (string, map)"
          ),
          "store"         => fun_ref(
            method(:StoreExpertForwardersPage),
            "void (string, map)"
          ),
          "help"          => Ops.get_string(@HELPS, "forwarders", "")
        },
        "basic_options" => {
          "widget"        => :custom,
          "custom_widget" => VBox(),
          "init"          => fun_ref(
            method(:InitExpertBasicOptionsPage),
            "void (string)"
          ),
          "handle"        => fun_ref(
            method(:HandleExpertBasicOptionsPage),
            "symbol (string, map)"
          ),
          "store"         => fun_ref(
            method(:StoreExpertBasicOptionsPage),
            "void (string, map)"
          ),
          "help"          => Ops.get_string(@HELPS, "basic_options", "")
        },
        "logging"       => {
          "widget"        => :custom,
          "custom_widget" => VBox(),
          "init"          => fun_ref(
            method(:InitExpertLoggingPage),
            "void (string)"
          ),
          "handle"        => fun_ref(
            method(:HandleExpertLoggingPage),
            "symbol (string, map)"
          ),
          "store"         => fun_ref(
            method(:StoreExpertLoggingPage),
            "void (string, map)"
          ),
          "help"          => Ops.get_string(@HELPS, "logging", "")
        },
        "acls"          => {
          "widget"        => :custom,
          "custom_widget" => VBox(),
          "init"          => fun_ref(
            method(:InitExpertAclPage),
            "void (string)"
          ),
          "handle"        => fun_ref(
            method(:HandleExpertAclPage),
            "symbol (string, map)"
          ),
          "store"         => fun_ref(
            method(:StoreExpertAclPage),
            "void (string, map)"
          ),
          "help"          => Ops.get_string(@HELPS, "acls", "")
        },
        "tsig_keys"     => CWMTsigKeys.CreateWidget(
          {
            "get_keys_info" => fun_ref(
              DnsTsigKeys.method(:GetTSIGKeys),
              "map <string, any> ()"
            ),
            "set_keys_info" => fun_ref(
              DnsTsigKeys.method(:SetTSIGKeys),
              "void (map <string, any>)"
            )
          }
        ),
        "keys"          => {
          "widget"        => :custom,
          "custom_widget" => VBox(),
          "help"          => Ops.get_string(@HELPS, "keys", "")
        },
        "zones"         => {
          "widget"        => :custom,
          "custom_widget" => VBox(),
          "init"          => fun_ref(
            method(:InitExpertZonesPage),
            "void (string)"
          ),
          "handle"        => fun_ref(
            method(:HandleExpertZonesPage),
            "symbol (string, map)"
          ),
          "store"         => fun_ref(
            method(:StoreExpertZonesPage),
            "void (string, map)"
          ),
          "help"          => Ops.get_string(@HELPS, "zones", "")
        },
        "set_icon"      => {
          "widget"        => :custom,
          "custom_widget" => Empty(),
          "init"          => fun_ref(
            method(:InitDNSSErverIcon),
            "void (string)"
          ),
          "help"          => " "
        }
      }
    end

    # Returns the status widget for service
    #
    # @return [::UI::ServiceStatus] status widget
    #
    # @see #service
    def status_widget
      @status_widget ||= ::UI::ServiceStatus.new(service)
    end

    # Returns the 'named' systemd service
    #
    # @return [SystemdService] 'named' systemd service instance
    def service
      @service ||= SystemdService.find("named")
    end
  end
end
