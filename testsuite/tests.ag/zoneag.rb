# encoding: utf-8

# File:
#  zoneag.ycp
#
# Module:
#  DNS Server Configuration
#
# Summary:
#  Testsuite
#
# Authors:
#  Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
module Yast
  class ZoneagClient < Client
    def main
      # testedfiles: zoneag.ycp

      @old = WFM.SCRGetDefault

      @h = WFM.SCROpen("ag_dns_zone", false)
      return if Ops.less_than(@h, 1)

      @server = []
      @peer = []
      @fudge = []

      WFM.SCRSetDefault(@h)

      @zone = Convert.to_map(SCR.Read(path("."), "zone"))
      Builtins.y2milestone("Zone: %1", @zone)

      @ret = SCR.Write(path("."), ["zone_new", @zone])
      Builtins.y2milestone("Write ret: %1", @ret)

      WFM.SCRSetDefault(@old)
      Builtins.y2milestone(
        "New file: %1",
        SCR.Read(path(".target.string"), "zone_new")
      )
      WFM.SCRClose(@h)

      nil
    end
  end
end

Yast::ZoneagClient.new.main
