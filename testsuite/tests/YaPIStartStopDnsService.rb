# encoding: utf-8

# File:	YaPIStartStopDnsService.ycp
# Package:	Configuration of dns-server
# Summary:	Testsuite for starting/stopping dns-server
# Authors:	Jiri Srain <jsrain@suse.cz>, Lukas Ocilka <locilka@suse.cz>
# Copyright:	Copyright 2004, Novell, Inc.  All rights reserved.
#
# $Id$
#
# Testsuite for starting/stopping dns-server
require "yast"

module Yast
  class YaPIStartStopDnsServiceClient < Client
    def main
      Yast.include self, "testsuite.rb"
      # testedfiles: DnsServer.pm DNSD.pm

      @I_READ = {
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
        "sysconfig" => {
          "SuSEfirewall2"     => {
            "FW_ALLOW_FW_TRACEROUTE"   => "yes",
            "FW_AUTOPROTECT_SERVICES"  => "no",
            "FW_DEV_DMZ"               => "",
            "FW_DEV_EXT"               => "eth-id-00:c0:df:22:c6:a8",
            "FW_DEV_INT"               => "",
            "FW_IPSEC_TRUST"           => "no",
            "FW_LOG_ACCEPT_ALL"        => "no",
            "FW_LOG_ACCEPT_CRIT"       => "yes",
            "FW_LOG_DROP_ALL"          => "no",
            "FW_LOG_DROP_CRIT"         => "yes",
            "FW_MASQUERADE"            => "no",
            "FW_MASQ_NETS"             => "",
            "FW_PROTECT_FROM_INTERNAL" => "yes",
            "FW_ROUTE"                 => "no",
            "FW_SERVICES_DMZ_IP"       => "",
            "FW_SERVICES_DMZ_TCP"      => "",
            "FW_SERVICES_DMZ_UDP"      => "",
            "FW_SERVICES_EXT_IP"       => "",
            "FW_SERVICES_EXT_RPC"      => "nlockmgr status nfs nfs_acl mountd ypserv fypxfrd ypbind ypasswdd",
            "FW_SERVICES_EXT_TCP"      => "32768 5801 5901 dixie domain hostname microsoft-ds netbios-dgm netbios-ns netbios-ssn nfs ssh sunrpc",
            "FW_SERVICES_EXT_UDP"      => "222 bftp domain ipp sunrpc",
            "FW_SERVICES_INT_IP"       => "",
            "FW_SERVICES_INT_TCP"      => "ddd eee fff 44 55 66",
            "FW_SERVICES_INT_UDP"      => "aaa bbb ccc 11 22 33"
          },
          "personal-firewall" => { "REJECT_ALL_INCOMING_CONNECTIONS" => "" },
          "console"           => { "CONSOLE_ENCODING" => "utf8" },
          "language"          => {
            "RC_LANG"        => "en_US.UTF-8",
            "ROOT_USES_LANG" => "ctype"
          }
        },
        "target"    => {
          "yast2" => { "lang2iso.ycp" => {} },
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
          }
        }
      }
      @I_WRITE = {}
      @I_EXEC = {}

      TESTSUITE_INIT([@I_READ, @I_WRITE, @I_EXEC], nil)

      Yast.import "YaPI::DNSD"
      Yast.import "Mode"

      Mode.SetMode("test")

      DUMP("==========================================================")
      TEST(lambda { YaPI::DNSD.StartDnsService({}) }, [], nil)
      DUMP("==========================================================")
      TEST(lambda { YaPI::DNSD.StopDnsService({}) }, [], nil)
      DUMP("==========================================================")
      TEST(lambda { YaPI::DNSD.GetDnsServiceStatus({}) }, [], nil)
      DUMP("==========================================================")

      nil
    end
  end
end

Yast::YaPIStartStopDnsServiceClient.new.main
