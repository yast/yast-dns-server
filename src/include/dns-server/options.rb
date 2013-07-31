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
  module DnsServerOptionsInclude
    def initialize_dns_server_options(include_target)
      textdomain "dns-server"

      Yast.import "Label"
      Yast.import "CWM"
      Yast.import "DnsServer"
    end

    # global table fallback handlers

    # Fallback initialization function of a table entry / popup
    # @param [Object] opt_id any option id
    # @param [String] opt_key any option key
    def globalPopupInit(opt_id, opt_key)
      opt_id = deep_copy(opt_id)
      if opt_id != nil
        oid = Convert.to_integer(opt_id)
        UI.ChangeWidget(
          Id(opt_key),
          :Value,
          Ops.get_string(@current_section, [oid, "value"], "")
        )
      end
      UI.SetFocus(Id(opt_key))

      nil
    end

    # Fallback store function of a table entry / popup
    # @param [Object] opt_id any option id
    # @param [String] opt_key any option key
    def globalPopupStore(opt_id, opt_key)
      opt_id = deep_copy(opt_id)
      if opt_id == nil
        new_opt = {
          "key"   => opt_key,
          "value" => UI.QueryWidget(Id(opt_key), :Value)
        }
        @current_section = Builtins.add(@current_section, new_opt)
      else
        oid = Convert.to_integer(opt_id)
        Ops.set(
          @current_section,
          [oid, "value"],
          UI.QueryWidget(Id(opt_key), :Value)
        )
      end
      DnsServer.SetModified

      nil
    end

    # Fallback summary function of a table entry / popup
    # @param [Object] opt_id any option id
    # @param [String] opt_key any option key
    # @return [String] table entry summary
    def globalTableEntrySummary(opt_id, opt_key)
      opt_id = deep_copy(opt_id)
      oid = Convert.to_integer(opt_id)
      Builtins.sformat(
        "%1",
        Ops.get_string(@current_section, [oid, "value"], "")
      )
    end


    # master domain table fallback handlers

    # Fallback initialization function of a table entry / popup
    # @param [Object] opt_id any option id
    # @param [String] opt_key any option key
    def masterPopupInit(opt_id, opt_key)
      opt_id = deep_copy(opt_id)
      index = Convert.to_integer(opt_id)
      key = ""
      value = ""
      if index != nil
        key = Ops.get_string(@current_zone, ["records", index, "key"], "")
        value = Ops.get_string(@current_zone, ["records", index, "value"], "")
      end
      UI.ChangeWidget(:key, :Value, key)
      UI.ChangeWidget(:value, :Value, value)
      UI.SetFocus(:key)

      nil
    end

    # Fallback store function of a table entry / popup
    # @param [Object] opt_id any option id
    # @param [String] opt_key any option key
    def masterPopupStore(opt_id, opt_key)
      opt_id = deep_copy(opt_id)
      index = Convert.to_integer(opt_id)
      key = Convert.to_string(UI.QueryWidget(:key, :Value))
      value = Convert.to_string(UI.QueryWidget(:value, :Value))
      if index != nil
        @current_zone_upd_ops = Builtins.add(
          @current_zone_upd_ops,
          {
            "operation" => "delete",
            "type"      => opt_key,
            "key"       => Ops.get_string(
              @current_zone,
              ["records", index, "key"],
              ""
            ),
            "value"     => Ops.get_string(
              @current_zone,
              ["records", index, "value"],
              ""
            )
          }
        )
        Ops.set(@current_zone, ["records", index, "value"], value)
        Ops.set(@current_zone, ["records", index, "key"], key)
      else
        new_rec = { "key" => key, "value" => value, "type" => opt_key }
        Ops.set(
          @current_zone,
          "records",
          Builtins.add(Ops.get_list(@current_zone, "records", []), new_rec)
        )
      end
      @current_zone_upd_ops = Builtins.add(
        @current_zone_upd_ops,
        {
          "operation" => "add",
          "type"      => opt_key,
          "key"       => key,
          "value"     => value
        }
      )

      nil
    end

    # Fallback summary function of a table entry / popup
    # @param [Object] opt_id any option id
    # @param [String] opt_key any option key
    # @return [String] table entry summary
    def masterTableEntrySummary(opt_id, opt_key)
      opt_id = deep_copy(opt_id)
      index = Convert.to_integer(opt_id)
      addr = Ops.get_string(@current_zone, ["records", index, "value"], "A")
      # %1 is usually an IP address
      Builtins.sformat(_("Unknown Record Type: %1"), addr)
    end

    # Fallback function for determining the first column of the table
    # in order not to depend on the option key
    # @param [Object] opt_id any option id
    # @param [String] opt_key any option key
    # @return [String] the table entry
    def masterTableLabelFunc(opt_id, opt_key)
      opt_id = deep_copy(opt_id)
      index = Convert.to_integer(opt_id)
      Ops.get_string(@current_zone, ["records", index, "key"], "")
    end

    # A popup

    def ASummary(opt_id, key)
      opt_id = deep_copy(opt_id)
      index = Convert.to_integer(opt_id)
      addr = Ops.get_string(@current_zone, ["records", index, "value"], "A")
      # table entry, %1 is IP address
      Builtins.sformat(_("Host %1"), addr)
    end

    def getAPopup
      {
        "table" => {
          "summary" => fun_ref(method(:ASummary), "string (any, string)"),
          # combo box item, A is more technical description
          "label"   => _(
            "A -- Domain Name Translation"
          )
        },
        "popup" => {
          "widget"        => :custom,
          "custom_widget" => HBox(
            HSpacing(1),
            VBox(
              HSpacing(50),
              InputField(Id(:key), Opt(:hstretch), Label.HostName),
              VSpacing(2),
              # text entry
              InputField(Id(:value), Opt(:hstretch), _("&IP Addresses")),
              VSpacing(1)
            ),
            HSpacing(1)
          )
        }
      }
    end


    # CNAME popup

    def CNAMESummary(opt_id, key)
      opt_id = deep_copy(opt_id)
      index = Convert.to_integer(opt_id)
      addr = Ops.get_string(@current_zone, ["records", index, "value"], "A")
      # table entry, %1 is host name
      Builtins.sformat(_("Alias for %1"), addr)
    end

    def getCNAMEPopup
      {
        "table" => {
          "summary" => fun_ref(method(:CNAMESummary), "string (any, string)"),
          # combo box item, CNAME is more technical description
          "label"   => _(
            "CNAME -- Alias for Domain Name"
          )
        },
        "popup" => {
          "widget"        => :custom,
          "custom_widget" => HBox(
            HSpacing(1),
            VBox(
              HSpacing(30),
              # text entry
              InputField(Id(:key), Opt(:hstretch), _("&Alias")),
              VSpacing(1),
              # text entry
              InputField(Id(:value), Opt(:hstretch), _("&Base Host Name")),
              VSpacing(1)
            ),
            HSpacing(1)
          )
        }
      }
    end


    # PTR popup

    def PTRSummary(opt_id, key)
      opt_id = deep_copy(opt_id)
      index = Convert.to_integer(opt_id)
      addr = Ops.get_string(@current_zone, ["records", index, "value"], "A")
      # table entry, %1 is host name
      Builtins.sformat(_("Pointer to %1"), addr)
    end

    def getPTRPopup
      {
        "table" => {
          "summary" => fun_ref(method(:PTRSummary), "string (any, string)"),
          # combo box item, PTR is more technical description
          "label"   => _(
            "PTR -- Reverse Translation"
          )
        },
        "popup" => {
          "widget"        => :custom,
          "custom_widget" => HBox(
            HSpacing(1),
            VBox(
              HSpacing(30),
              # text entry
              InputField(Id(:key), Opt(:hstretch), _("&IP Address")),
              VSpacing(1),
              # text entry
              InputField(Id(:value), Opt(:hstretch), Label.HostName),
              VSpacing(1)
            ),
            HSpacing(1)
          )
        }
      }
    end



    def NSSummary(opt_id, key)
      opt_id = deep_copy(opt_id)
      index = Convert.to_integer(opt_id)
      addr = Ops.get_string(@current_zone, ["records", index, "value"], "A")
      # table entry, %1 is host name
      Builtins.sformat(_("Name Server %1"), addr)
    end

    def getNSPopup
      {
        "table" => {
          "summary" => fun_ref(method(:NSSummary), "string (any, string)"),
          # combo box item, NS is more technical description
          "label"   => _(
            "NS -- Name Server"
          )
        },
        "popup" => {
          "widget"        => :custom,
          "custom_widget" => HBox(
            HSpacing(1),
            VBox(
              HSpacing(30),
              # text entry
              InputField(Id(:key), Opt(:hstretch), _("&Domain")),
              VSpacing(1),
              # text entry
              InputField(Id(:value), Opt(:hstretch), _("&Name Server")),
              VSpacing(1)
            ),
            HSpacing(1)
          )
        }
      }
    end

    def MXSummary(opt_id, key)
      opt_id = deep_copy(opt_id)
      index = Convert.to_integer(opt_id)
      addr = Ops.get_string(@current_zone, ["records", index, "value"], "A")
      l = Builtins.splitstring(addr, " ")
      l = Builtins.filter(l) { |s| s != "" }
      prio = Ops.get(l, 0, "")
      Ops.set(l, 0, "")
      l = Builtins.filter(l) { |s| s != "" }
      addr = Builtins.mergestring(l, " ")
      # table entry, %1 is host name, %2 is integer
      Builtins.sformat(_("Mail Relay %1, Priority %2"), addr, prio)
    end

    def MXInit(opt_id, key)
      opt_id = deep_copy(opt_id)
      index = Convert.to_integer(opt_id)
      key = ""
      value = ""
      if index != nil
        key = Ops.get_string(@current_zone, ["records", index, "key"], "")
        value = Ops.get_string(@current_zone, ["records", index, "value"], "")
      end
      l = Builtins.splitstring(value, " ")
      l = Builtins.filter(l) { |s| s != "" }
      prio = Ops.get(l, 0, "")
      Ops.set(l, 0, "")
      l = Builtins.filter(l) { |s| s != "" }
      value = Builtins.mergestring(l, " ")
      UI.ChangeWidget(:key, :Value, key)
      UI.ChangeWidget(:value, :Value, value)
      UI.ChangeWidget(:prio, :Value, Builtins.tointeger(prio))
      UI.SetFocus(:key)

      nil
    end

    def MXStore(opt_id, opt_key)
      opt_id = deep_copy(opt_id)
      index = Convert.to_integer(opt_id)
      key = Convert.to_string(UI.QueryWidget(:key, :Value))
      value = Convert.to_string(UI.QueryWidget(:value, :Value))
      prio = Convert.to_integer(UI.QueryWidget(:prio, :Value))
      value = Builtins.sformat("%1 %2", prio, value)
      if index != nil
        @current_zone_upd_ops = Builtins.add(
          @current_zone_upd_ops,
          {
            "operation" => "delete",
            "type"      => opt_key,
            "key"       => Ops.get_string(
              @current_zone,
              ["records", index, "key"],
              ""
            ),
            "value"     => Ops.get_string(
              @current_zone,
              ["records", index, "value"],
              ""
            )
          }
        )
        Ops.set(@current_zone, ["records", index, "value"], value)
        Ops.set(@current_zone, ["records", index, "key"], key)
      else
        new_rec = { "key" => key, "value" => value, "type" => opt_key }
        Ops.set(
          @current_zone,
          "records",
          Builtins.add(Ops.get_list(@current_zone, "records", []), new_rec)
        )
      end
      @current_zone_upd_ops = Builtins.add(
        @current_zone_upd_ops,
        {
          "operation" => "add",
          "type"      => opt_key,
          "key"       => key,
          "value"     => value
        }
      )

      nil
    end

    def getMXPopup
      {
        "table" => {
          "summary" => fun_ref(method(:MXSummary), "string (any, string)"),
          # combo box item, MX is more technical description
          "label"   => _(
            "MX -- Mail Relay"
          )
        },
        "popup" => {
          "init"          => fun_ref(method(:MXInit), "void (any, string)"),
          "store"         => fun_ref(method(:MXStore), "void (any, string)"),
          "widget"        => :custom,
          "custom_widget" => HBox(
            HSpacing(1),
            VBox(
              HSpacing(30),
              # text entry
              InputField(Id(:key), Opt(:hstretch), _("&Domain Name")),
              VSpacing(1),
              # text entry
              InputField(Id(:value), Opt(:hstretch), _("&Mail Relay")),
              VSpacing(1),
              # int field
              IntField(Id(:prio), _("&Priority"), 0, 100, 0),
              VSpacing(1)
            ),
            HSpacing(1)
          )
        }
      }
    end

    # Initialize all poups
    # @return [Hash] description of all popups/options
    def InitPopups
      {
        "A"     => getAPopup,
        "CNAME" => getCNAMEPopup,
        "PTR"   => getPTRPopup,
        "NS"    => getNSPopup,
        "MX"    => getMXPopup
      }
    end
  end
end
