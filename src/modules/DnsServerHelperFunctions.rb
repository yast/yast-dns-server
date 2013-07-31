# encoding: utf-8

# File:	modules/DnsServerHelperFunctions.ycp
# Package:	Configuration of dns-server
# Summary:	Module containing helper functions.
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# $Id$
#
# Module handles dynamic update of zone using 'nsupdate' command.
# Automatic generation of connected zones and much more!
require "yast"

module Yast
  class DnsServerHelperFunctionsClass < Module
    def main
      textdomain "dns-server"

      Yast.import "DnsServer"
      Yast.import "DnsServerAPI"

      @skip_converting_to_relative = {
        "key"   => [],
        "value" => ["TXT", "SPF", "SRV"]
      }
    end

    # Returns whether zone is a reverse-zone type
    #
    # @param [String] zone
    # @return [Boolean] if zone is reverse type
    def IsReverseZone(zone)
      if zone == nil || zone == ""
        Builtins.y2error("Wrong zone name: '%1'", zone)
        return nil
      end

      if Builtins.regexpmatch(zone, ".*\\.in-addr\\.arpa\\.?$") ||
          Builtins.regexpmatch(zone, ".*\\.ip6\\.arpa\\.?$")
        return true
      else
        return false
      end
    end

    def IsInternalZone(zone_name)
      if zone_name == "" || zone_name == nil
        Builtins.y2error("Uknown zone: %1", zone_name)
        return nil
      end

      zone_name == "." || zone_name == "0.0.127.in-addr.arpa" ||
        zone_name == "localhost"
    end

    def HandleNsupdate(update_record, operation, current_zone)
      update_record = deep_copy(update_record)
      if !Builtins.regexpmatch(operation, "^(add|delete)$")
        Builtins.y2error(
          "allowed operation is 'add' or 'delete', not '%1'",
          operation
        )
        return false
      end
      if Ops.get_string(update_record, "type", "") == "" ||
          Ops.get_string(update_record, "key", "") == ""
        Builtins.y2error("$[key:?] and $[type:?] is not defined")
        return false
      end

      __current_zone_ = Ops.add(
        Ops.add(".", Ops.get_string(current_zone.value, "zone", "")),
        Builtins.regexpmatch(
          Ops.get_string(current_zone.value, "zone", ""),
          "\\.$"
        ) ? "" : "."
      )

      # relative hostnames are converted to absolute
      if Builtins.regexpmatch(
          Builtins.tolower(Ops.get_string(update_record, "type", "")),
          "^(a|ns|mx|cname)$"
        )
        if Builtins.regexpmatch(
            Ops.get_string(update_record, "key", ""),
            ".*[^.]$"
          )
          Ops.set(
            update_record,
            "key",
            Ops.add(Ops.get_string(update_record, "key", ""), __current_zone_)
          )
        end
      end
      if Builtins.regexpmatch(
          Builtins.tolower(Ops.get_string(update_record, "type", "")),
          "^(ns|mx|cname)$"
        )
        if Builtins.regexpmatch(
            Ops.get_string(update_record, "value", ""),
            ".*[^.]$"
          )
          Ops.set(
            update_record,
            "value",
            Ops.add(Ops.get_string(update_record, "value", ""), __current_zone_)
          )
        end
      end

      if Builtins.tolower(Ops.get_string(update_record, "type", "")) == "txt"
        Ops.set(
          update_record,
          "value",
          Ops.add(
            Ops.add(
              "\"",
              Builtins.mergestring(
                Builtins.splitstring(
                  Ops.get_string(update_record, "value", ""),
                  "\""
                ),
                "\\\""
              )
            ),
            "\""
          )
        )
      end

      # If absolute name && doesn't match the current zone...
      # nsupdate would refuse such change
      if Builtins.regexpmatch(Ops.get_string(update_record, "key", ""), "\\.$") &&
          !Builtins.issubstring(
            Ops.get_string(update_record, "key", ""),
            __current_zone_
          ) &&
          Ops.get_string(
            # e.g., NS for zone
            update_record,
            "key",
            ""
          ) !=
            Ops.add(Ops.get_string(current_zone.value, "zone", ""), ".")
        Builtins.y2warning(
          "Wrong record '%1' for zone '%2'",
          Ops.get_string(update_record, "key", ""),
          __current_zone_
        )
        return false
      end

      Ops.set(
        current_zone.value,
        "update_actions",
        Builtins.add(
          Ops.get_list(current_zone.value, "update_actions", []),
          {
            "operation" => operation,
            "type"      => Ops.get_string(update_record, "type", ""),
            "key"       => Ops.get_string(update_record, "key", ""),
            "value"     => Ops.get_string(update_record, "value", "")
          }
        )
      )

      true
    end

    def MakeFQDNRecord(one_record, from_zone)
      one_record = deep_copy(one_record)
      # relative name to the zone name
      if !Builtins.regexpmatch(Ops.get_string(one_record, "key", ""), "\\.$")
        Ops.set(
          one_record,
          "key",
          Ops.add(
            Ops.add(Ops.get_string(one_record, "key", ""), "."),
            from_zone.value
          )
        )
      end

      deep_copy(one_record)
    end

    def RegenerateReverseZoneFrom(regenerate_zone, from_zone)
      Builtins.y2milestone(
        "Regenerating zone %1 from zone %2",
        regenerate_zone,
        from_zone
      )

      current_zone = {}

      if !IsReverseZone(regenerate_zone)
        Builtins.y2error("Not a reverse zone: %1", regenerate_zone)
        return
      end

      if IsReverseZone(from_zone)
        Builtins.y2error("Not a forward zone: %1", from_zone)
        return
      end

      # Fetch the original zone records
      # to generate reverse records later
      index = DnsServer.FindZone(from_zone)
      if index == nil || Ops.less_than(index, 0)
        Builtins.y2error("Cannot find zone: %1", from_zone)
        return
      end

      DnsServer.SelectZone(index)
      current_zone = DnsServer.FetchCurrentZone
      original_zone_records = Ops.get_list(current_zone, "records", [])

      # Fetch the zone to edit
      index = DnsServer.FindZone(regenerate_zone)
      if index == nil || Ops.less_than(index, 0)
        Builtins.y2error("Cannot find zone: %1", regenerate_zone)
        return
      end

      DnsServer.SelectZone(index)
      current_zone = DnsServer.FetchCurrentZone

      # we leave these records untouched
      leave_these_records = ["SOA", "NS"]

      # Delete all current records from zone
      counter = -1
      zone_records = Ops.get_list(current_zone, "records", [])

      # run through copy of the list of records
      Builtins.foreach(zone_records) do |one_record|
        counter = Ops.add(counter, 1)
        if Builtins.contains(
            leave_these_records,
            Builtins.tostring(Ops.get_string(one_record, "type", ""))
          )
          next
        end
        # change it to nil and remove later
        Ops.set(current_zone, ["records", counter], nil)
        # ORIGIN is a special case, handled by bind itself if zone is dynamic
        if Builtins.tostring(Ops.get_string(one_record, "type", "")) != "ORIGIN"
          # dynamic zone
          current_zone_ref = arg_ref(current_zone)
          HandleNsupdate(one_record, "delete", current_zone_ref)
          current_zone = current_zone_ref.value
        end
      end

      # remove nil records
      Ops.set(
        current_zone,
        "records",
        Builtins.filter(Ops.get_list(current_zone, "records", [])) do |one_record|
          one_record != nil
        end
      )

      # Creating FQDN
      if !Builtins.regexpmatch(regenerate_zone, "\\.$")
        regenerate_zone = Ops.add(regenerate_zone, ".")
      end
      if !Builtins.regexpmatch(from_zone, "\\.$")
        from_zone = Ops.add(from_zone, ".")
      end

      new_record = {}

      # Go through all A, resp. AAAA, and add them in reverse order
      # IPv4 or IPv6?
      if Builtins.regexpmatch(regenerate_zone, "\\.ip6\\.arpa\\.?$")
        Builtins.foreach(original_zone_records) do |one_record|
          if Ops.get_string(one_record, "type", "") == "AAAA"
            # FIXME: make a PTR
            one_record = (
              from_zone_ref = arg_ref(from_zone);
              _MakeFQDNRecord_result = MakeFQDNRecord(one_record, from_zone_ref);
              from_zone = from_zone_ref.value;
              _MakeFQDNRecord_result
            )
            new_record = {
              "key"   => DnsServerAPI.GetReverseIPforIPv6(
                Ops.get_string(one_record, "value", "")
              ),
              "type"  => "PTR",
              "value" => Ops.get_string(one_record, "key", "")
            }
            # FIXME: something more offective?
            Ops.set(
              current_zone,
              "records",
              Builtins.add(
                Ops.get_list(current_zone, "records", []),
                new_record
              )
            )
            current_zone_ref = arg_ref(current_zone)
            HandleNsupdate(new_record, "add", current_zone_ref)
            current_zone = current_zone_ref.value
          end
        end
      else
        Builtins.foreach(original_zone_records) do |one_record|
          if Ops.get_string(one_record, "type", "") == "A"
            one_record = (
              from_zone_ref = arg_ref(from_zone);
              _MakeFQDNRecord_result = MakeFQDNRecord(one_record, from_zone_ref);
              from_zone = from_zone_ref.value;
              _MakeFQDNRecord_result
            )
            new_record = {
              "key"   => DnsServerAPI.GetReverseIPforIPv4(
                Ops.get_string(one_record, "value", "")
              ),
              "type"  => "PTR",
              "value" => Ops.get_string(one_record, "key", "")
            }
            # FIXME: something more offective?
            Ops.set(
              current_zone,
              "records",
              Builtins.add(
                Ops.get_list(current_zone, "records", []),
                new_record
              )
            )
            current_zone_ref = arg_ref(current_zone)
            HandleNsupdate(new_record, "add", current_zone_ref)
            current_zone = current_zone_ref.value
          end
        end
      end

      DnsServer.StoreCurrentZone(current_zone)
      DnsServer.StoreZone

      nil
    end

    def RRToRelativeName(absolute_name, zone_name, record_type, key_or_value)
      if absolute_name == nil || zone_name == nil
        Builtins.y2error(
          "Erroneous record: %1/%2/%3/%4",
          absolute_name,
          zone_name,
          record_type,
          key_or_value
        )
        return nil
      end

      if key_or_value != "key" && key_or_value != "value"
        Builtins.y2error("Unknown key/value %1", key_or_value)
        return absolute_name
      end

      # these records are not wanted to be converted to a relative name
      if Builtins.contains(
          Ops.get(@skip_converting_to_relative, key_or_value, []),
          Builtins.toupper(record_type)
        )
        Builtins.y2debug("Not converting %1/%2", key_or_value, record_type)
        return absolute_name
      end

      remove_this_to_be_relative = Ops.add(Ops.add("\\.", zone_name), "\\.$")
      relative_name = Builtins.regexpsub(
        absolute_name,
        Ops.add("([^ \t]*)", remove_this_to_be_relative),
        "\\1"
      )
      return relative_name if relative_name != nil

      absolute_name
    end

    publish :function => :IsReverseZone, :type => "boolean (string)"
    publish :function => :IsInternalZone, :type => "boolean (string)"
    publish :function => :HandleNsupdate, :type => "boolean (map, string, map <string, any> &)"
    publish :function => :MakeFQDNRecord, :type => "map (map, string &)"
    publish :function => :RegenerateReverseZoneFrom, :type => "void (string, string)"
    publish :function => :RRToRelativeName, :type => "string (string, string, string, string)"
  end

  DnsServerHelperFunctions = DnsServerHelperFunctionsClass.new
  DnsServerHelperFunctions.main
end
