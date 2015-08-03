# encoding: utf-8

# File:	clients/dns-server.ycp
# Package:	Configuration of dns-server
# Summary:	Main file
# Authors:	Jiri Srain <jsrain@suse.cz>
#		Lukas Ocilka <locilka@suse.cz>
#
# $Id$
#
# Main file for dns-server configuration. Uses all other files.
module Yast
  class DnsServerClient < Client
    def main

      #**
      # <h3>Configuration of the dns-server</h3>

      textdomain "dns-server"
      Yast.import "DnsServerUI"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("DnsServer module started")

      # main ui function
      @ret = nil

      # there are some arguments - starting commandline
      if Ops.greater_than(Builtins.size(WFM.Args), 0)
        Yast.include self, "dns-server/cmdline.rb" 
      else
        @ret = DnsServerUI.DnsSequence
        Builtins.y2debug("ret=%1", @ret)
      end

      # Finish
      Builtins.y2milestone("DnsServer module finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end
  end
end

Yast::DnsServerClient.new.main
