# encoding: utf-8

# File:	Read.ycp
# Package:	Configuration of dns-server
# Summary:	Testsuite for reading configuration
# Authors:	Jiri Srain <jsrain@suse.cz>, Lukas Ocilka <locilka@suse.cz>
# Copyright:	Copyright 2004, Novell, Inc.  All rights reserved.
#
# $Id$
#
# Testsuite for reading configuration for dns-server
require "yast"

module Yast
  class ReadClient < Client
    def main
      Yast.include self, "testsuite.rb"
      # testedfiles: DnsServer.pm DNSD.pm DnsZones.pm

      @I_READ = {
        "etc"       => {
          "nsswitch_conf" => "",
          "security"      => { "v" => { "pam_unix2" => "" } }
        },
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
            "USE_DESKTOP_SCHEDULER"           => "0",
            "IO_SCHEDULER"                    => "cfg",
            "UI_MODE"                         => "expert",
            "ENABLE_AUTOLOGIN"                => "0",
            "EVMS_CONFIG"                     => "0",
            "INCOMPLETE_TRANSLATION_TRESHOLD" => "95"
          }
        },
        "sysconfig" => {
          "personal-firewall" => { "REJECT_ALL_INCOMING_CONNECTIONS" => "" },
          "displaymanager"    => { "DISPLAYMANAGER" => "" },
          "network"           => { "NETCONFIG_DNS_FORWARDER"  => "resolver" },
        },
        "target"    => {
          "stat"  => {
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
          "lstat" => {},
          "ycp"   => {}
        }
      }
      @I_WRITE = {}
      @I_EXEC = {}

      TESTSUITE_INIT([@I_READ, @I_WRITE, @I_EXEC], nil)

      Yast.import "Progress"
      Yast.import "DnsServer"
      Yast.import "Mode"

      Mode.SetMode("test")

      # avoid reading SuSEFirewall sysconfig
      @progress_orig = Progress.set(false)

      @READ = {
        "passwd"    => { "passwd" => { "pluslines" => [] } },
        "etc"       => {
          "nsswitch_conf" => "",
          "security"      => { "v" => { "pam_unix2" => "" } }
        },
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
            "USE_DESKTOP_SCHEDULER"           => "0",
            "IO_SCHEDULER"                    => "cfg",
            "UI_MODE"                         => "expert",
            "ENABLE_AUTOLOGIN"                => "0",
            "EVMS_CONFIG"                     => "0",
            "INCOMPLETE_TRANSLATION_TRESHOLD" => "95"
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
        "target"    => {
          "stat" => {
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
          "ycp"  => {}
        },
        "dns"       => {
          "named" => {
            "section" => { "options" => "", "zone \"example.org\" in" => "" },
            "value"   => {
              "options"               => {
                "directory" => ["\"/var/lib/named\""],
                "notify"    => ["no"]
              },
              "zone \"example.org\" in" => {
                "type" => ["master"],
                "file" => ["\"master/example.org\""]
              },
              "acl"                   => []
            }
          },
          "zone"  => {
            "TTL"     => "1W",
            "records" => [
              { "key" => "", "type" => "NS", "value" => "@" },
              { "key" => "", "type" => "A", "value" => "10.0.0.1" },
              { "key" => "server_name", "type" => "A", "value" => "10.0.0.2" }
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
          "ldap"              => {
            "BASE_CONFIG_DN" => "",
            "FILE_SERVER"    => "",
            "BIND_DN"        => ""
          },
          "personal-firewall" => { "REJECT_ALL_INCOMING_CONNECTIONS" => "" },
          "network"           => {
            "config" => {
              "MODIFY_NAMED_CONF_DYNAMICALLY"  => "yes",
              "MODIFY_RESOLV_CONF_DYNAMICALLY" => "yes",
              "NETCONFIG_DNS_POLICY"           => "STATIC",
              "NETCONFIG_DNS_STATIC_SERVERS"   => ""
            }
          },
          "console"           => { "CONSOLE_ENCODING" => "utf8" },
          "language"          => {
            "RC_LANG"        => "en_US.UTF-8",
            "ROOT_USES_LANG" => "ctype"
          },
          "displaymanager"    => { "DISPLAYMANAGER" => "" }
        },
        "target"    => {
          "yast2" => { "lang2iso.ycp" => {} },
          "size"  => 1,
          "stat"  => {
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
          "lstat" => {},
          "ycp"   => {}
        }
      }
      @WRITE = {}
      @EXEC = {
        "target" => {
          "bash_output" => { "exit" => 1, "stdout" => "", "stderr" => "" },
          "bash"        => 1
        },
        "passwd" => { "init" => true }
      }

      DUMP("=======================")
      TEST(lambda { DnsServer.Read }, [@READ, @WRITE, @EXEC], 0)
      DUMP("=======================")
      TEST(lambda { DnsServer.Export }, [@READ, @WRITE, @EXEC], 0)

      nil
    end
  end
end

Yast::ReadClient.new.main
