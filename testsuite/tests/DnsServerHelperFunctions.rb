# encoding: utf-8

# File:	DnsServerHelperFunctions.ycp
# Package:	Configuration of dns-server
# Summary:	Testsuite helper module
# Authors:	Lukas Ocilka <locilka@suse.com>
# Copyright:	Copyright 2012, Novell, Inc.  All rights reserved.
#
# $Id$
#
# Testsuite for helper functions module
module Yast
  class DnsServerHelperFunctionsClient < Client
    def main
      Yast.include self, "testsuite.rb"
      # testedfiles: DnsServerHelperFunctions.ycp

      @READ = {}
      @WRITE = {}
      @EXEC = {}

      TESTSUITE_INIT([@READ, @WRITE, @EXEC], nil)

      Yast.import "DnsServerHelperFunctions"
      Yast.import "Mode"

      Mode.SetMode("test")

      @zone = "example.com"

      DUMP("==========================================================")

      # cuts the zone name off
      TEST(lambda do
        DnsServerHelperFunctions.RRToRelativeName(
          Ops.add(Ops.add("dhcp1.", @zone), "."),
          @zone,
          "A",
          "key"
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)

      # CNAME - key can be relative
      TEST(lambda do
        DnsServerHelperFunctions.RRToRelativeName(
          Ops.add(Ops.add("relative-name-1.", @zone), "."),
          @zone,
          "cname",
          "key"
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)

      # CNAME - value can be relative
      TEST(lambda do
        DnsServerHelperFunctions.RRToRelativeName(
          Ops.add(Ops.add("relative-name-2.", @zone), "."),
          @zone,
          "cname",
          "value"
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)

      # cuts the zone name off (leaves subdomain)
      TEST(lambda do
        DnsServerHelperFunctions.RRToRelativeName(
          Ops.add(Ops.add("dhcp1.subdomain.", @zone), "."),
          @zone,
          "A",
          "key"
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)

      # different zone name
      TEST(lambda do
        DnsServerHelperFunctions.RRToRelativeName(
          Ops.add(Ops.add("dhcp1.different-", @zone), "."),
          @zone,
          "A",
          "key"
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)

      # TXT record (value), not changed
      TEST(lambda do
        DnsServerHelperFunctions.RRToRelativeName(
          Ops.add(Ops.add("v=spf1 include:", @zone), " -all"),
          @zone,
          "TXT",
          "value"
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)

      # TXT record (key), can be realtive
      TEST(lambda do
        DnsServerHelperFunctions.RRToRelativeName(
          Ops.add(Ops.add("some-text.", @zone), "."),
          @zone,
          "TXT",
          "key"
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)

      # SPF record (value), not changed
      TEST(lambda do
        DnsServerHelperFunctions.RRToRelativeName(
          Ops.add(Ops.add("v=spf1 include:", @zone), " -all"),
          @zone,
          "SPF",
          "value"
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)

      # SRV record (key) can be realtive
      TEST(lambda do
        DnsServerHelperFunctions.RRToRelativeName(
          Ops.add(Ops.add("_http._tcp.", @zone), "."),
          @zone,
          "SRV",
          "key"
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)

      # SRV record (value) can't be realtive
      TEST(lambda do
        DnsServerHelperFunctions.RRToRelativeName(
          Ops.add(Ops.add("0    5      80   ", @zone), "."),
          @zone,
          "SRV",
          "value"
        )
      end, [
        @READ,
        @WRITE,
        @EXEC
      ], nil)

      DUMP("==========================================================")

      nil
    end
  end
end

Yast::DnsServerHelperFunctionsClient.new.main
