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
    include Yast::Logger

    Yast.import "DnsServer"
    Yast.import "PackageSystem"

    def main

      #**
      # <h3>Configuration of the dns-server</h3>

      textdomain "dns-server"

      # The main ()
      log.info("----------------------------------------")
      log.info("DnsServer module started")

      # main ui function
      @ret = nil

      # there are some arguments - starting commandline
      if Ops.greater_than(Builtins.size(WFM.Args), 0)
        Yast.include self, "dns-server/cmdline.rb" 
      else
        @ret = packages_installed? ? run_sequence : :abort
        log.debug("ret=#{@ret}")
      end

      # Finish
      log.info("DnsServer module finished")
      log.info("----------------------------------------")

      @ret
    end
  end

  # Run DNS sequence
  #
  # @return [Symbol] Sequence result
  def run_sequence
    Yast.import "DnsServerUI"
    DnsServerUI.DnsSequence
  end

  # Checks if required packages are installed
  #
  # If package is not installed, asks the user to install it.
  #
  # @return [Boolean] true if the package is installed; false if not installed
  #                   and the user refuses to installed it.
  def packages_installed?
    if !PackageSystem.CheckAndInstallPackages(DnsServer.AutoPackages["install"])
      Popup.Error(_("YaST cannot continue the configuration\n" \
                    "without installing the required packages"))
      false
    else
      true
    end
  end
end
