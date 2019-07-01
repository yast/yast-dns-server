# encoding: utf-8

# File:	DNSServerAPI.ycp
# Package:	Configuration of dns-server
# Summary:	Testsuite for APIv2
# Authors:	Lukas Ocilka <locilka@suse.cz>
# Copyright:	Copyright 2004, Novell, Inc.  All rights reserved.
#
# $Id: DnsServerAPI.ycp 48293 2008-06-13 13:24:54Z locilka $
require "yast"

module Yast
  class DnsServerAPIClient < Client
    def main
      Yast.include self, "testsuite.rb"
      # testedfiles: DnsServerAPI.pm DnsZones.pm DnsServer.pm

      @READ = {
        "passwd"    => { "passwd" => { "pluslines" => [] } },
        "probe"     => {
          "architecture" => "i386",
          "has_apm"      => true,
          "has_pcmcia"   => false,
          "has_smp"      => false,
          "system"       => [],
          "memory"       => [],
          "cpu"          => [],
          "cdrom"        => { "manual" => [] },
          "floppy"       => { "manual" => [] },
          "is_uml"       => false
        },
        "product"   => {
          "features" => {
            "USE_DESKTOP_SCHEDULER" => "0",
            "IO_SCHEDULER"          => "cfg",
            "UI_MODE"               => "expert",
            "ENABLE_AUTOLOGIN"      => "0",
            "EVMS_CONFIG"           => "0"
          }
        },
        # Runlevel
        "init"      => {
          "scripts" => {
            "exists"   => true,
            "runlevel" => { "named" => { "start" => [], "stop" => [] } },
            # their contents is not important for ServiceAdjust
            "comment"  => {
              "named" => {}
            }
          }
        },
        "dns"       => {
          "named" => {
            "section" => { "options" => "", "zone \"localhost\" in" => "" },
            "value"   => {
              "options"               => {
                "directory" => ["\"/var/lib/named\""],
                "notify"    => ["no"]
              },
              "zone \"localhost\" in" => {
                "type" => ["master"],
                "file" => ["\"localhost.zone\""]
              },
              "acl"                   => []
            }
          },
          "zone"  => {
            "TTL"     => "1W",
            "records" => [
              { "key" => "", "type" => "NS", "value" => "@" },
              { "key" => "", "type" => "A", "value" => "127.0.0.1" },
              { "key" => "localhost2", "type" => "A", "value" => "127.0.0.2" }
            ],
            "soa"     => {
              "expiry"  => "6W",
              "mail"    => "root",
              "minimum" => "1W",
              "refresh" => "2D",
              "retry"   => "4H",
              "serial"  => 42,
              "server"  => "@",
              "zone"    => "@"
            }
          }
        },
        "sysconfig" => {
          "personal-firewall" => { "REJECT_ALL_INCOMING_CONNECTIONS" => "" },
          "network"           => {
            "config" => {
              "MODIFY_NAMED_CONF_DYNAMICALLY"  => "yes",
              "MODIFY_RESOLV_CONF_DYNAMICALLY" => "yes",
              "NETCONFIG_DNS_POLICY"           => "auto",
              "NETCONFIG_DNS_STATIC_SERVERS"   => "1.2.3.4",
              "NETCONFIG_DNS_FORWARDER"        => "resolver",
            }
          }
        },
        "target"    => {
          "stat"   => {
            "atime"   => 1101890288,
            "ctime"   => 1101890286,
            "gid"     => 0,
            "inode"   => 29236,
            "isblock" => false,
            "ischr"   => false,
            "isdir"   => false,
            "isfifo"  => false,
            "islink"  => false,
            "isreg"   => true,
            "issock"  => false,
            "mtime"   => 1101890286,
            "nlink"   => 1,
            "size"    => 804,
            "uid"     => 0
          },
          "lstat"  => {},
          "ycp"    => {},
          "yast2"  => { "lang2iso.ycp" => {} },
          "size"   => 1,
          "string" => "some text"
        }
      }
      @WRITE = { "target" => { "ycp" => true } }
      @EXEC = {
        "target" => {
          "bash_output" => { "exit" => 1, "stdout" => "", "stderr" => "" }
        },
        "passwd" => { "init" => true }
      }





      TESTSUITE_INIT([@READ, @WRITE, @EXEC], nil)

      Yast.import "DnsServerAPI"
      Yast.import "DnsServer"
      Yast.import "Mode"
      Yast.import "Progress"

      Mode.SetMode("test")

      @progress_orig = Progress.set(false)

      DUMP("==========================================================")

      TEST(lambda { DnsServerAPI.TimeToSeconds("3600") }, [@READ, @WRITE, @EXEC], nil)
      TEST(lambda { DnsServerAPI.TimeToSeconds("1D2h3S") }, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)
      TEST(lambda { DnsServerAPI.TimeToSeconds("1W3d4h1M") }, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)

      DUMP("==========================================================")

      TEST(lambda { DnsServerAPI.SecondsToHighestTimeUnit(3600) }, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)
      TEST(lambda { DnsServerAPI.SecondsToHighestTimeUnit(93603) }, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)
      TEST(lambda { DnsServerAPI.SecondsToHighestTimeUnit(878460) }, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)

      DUMP("==========================================================")

      # Reading the current configuration
      TEST(lambda { DnsServer.Read }, [@READ, @WRITE, @EXEC], nil)

      DUMP("==========================================================")

      # Adding already created zone
      TEST(lambda { DnsServerAPI.AddZone("example.com", "forward", {}) }, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)

      # Adding new zone
      TEST(lambda { DnsServerAPI.AddZone("example.com.new", "forward", {}) }, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)
      # Setting up invalid forwarder server
      TEST(lambda do
        DnsServerAPI.SetZoneForwarders(
          "example.com.new",
          ["192.168.0.1", "192.168.0.288"]
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)
      TEST(lambda do
        DnsServerAPI.SetZoneForwarders(
          "example.com.new",
          ["192.168.0.1", "192.168.0.2"]
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)
      TEST(lambda { DnsServerAPI.GetZoneForwarders("example.com.new") }, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)

      DUMP("==========================================================")

      # Adding new zone
      TEST(lambda do
        DnsServerAPI.AddZone(
          "example.stop.com",
          "slave",
          { "masterserver" => "1.2.3.4" }
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)
      # Setting up invalid master servers
      TEST(lambda do
        DnsServerAPI.SetZoneMasterServers(
          "example.stop.com",
          ["192.168.22.1", "192.168.33.2.888"]
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)
      TEST(lambda do
        DnsServerAPI.SetZoneMasterServers(
          "example.stop.com",
          ["192.168.22.1", "192.168.33.2"]
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)
      TEST(lambda { DnsServerAPI.GetZoneMasterServers("example.stop.com") }, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)

      DUMP("==========================================================")

      # Wrong IPv4
      TEST(lambda { DnsServerAPI.GetReverseIPforIPv4("100.200.300.400") }, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)
      TEST(lambda { DnsServerAPI.GetReverseIPforIPv4("10.20.30.40") }, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)

      DUMP("==========================================================")

      nil
    end
  end
end

Yast::DnsServerAPIClient.new.main
