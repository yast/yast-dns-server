# encoding: utf-8

module Yast
  class DnsServerUIClient < Client
    def main
      # testedfiles: DnsServerUI

      # While running tests, variable Y2ALLGLOBAL makes all functions global
      # thus we can test all internal functions

      Yast.include self, "testsuite.rb"

      Yast.import "DnsServerUI"

      # DnsServerUI::ChangeIPToLocalEquivalent
      DUMP("==========================================================")

      @ips = [
        "192.168.5.1",
        "238.11.26.25",
        "fe80::21c:c0ff:fe18:f01c",
        "trash"
      ]

      Builtins.foreach(@ips) { |ip| TEST(lambda do
        DnsServerUI.ChangeIPToLocalEquivalent(ip)
      end, [], nil) }

      DUMP("==========================================================")

      @READ = {}
      @WRITE = {}
      @EXEC = {
        "target" => {
          "bash_output" => {
            "exit"   => 0,
            "stdout" => "127.0.0.1\n" +
              "127.0.0.2\n" +
              "::1\n" +
              "192.168.5.1\n" +
              "238.11.26.25\n" +
              "fe80::21c:c0ff:fe18:f01c",
            "stderr" => ""
          }
        }
      }

      # DnsServerUI::CurrentlyUsedIPs
      TEST(lambda { DnsServerUI.CurrentlyUsedIPs(true) }, [@READ, @WRITE, @EXEC], nil)
      TEST(lambda { DnsServerUI.CurrentlyUsedIPs(false) }, [@READ, @WRITE, @EXEC], nil)

      DUMP("==========================================================")

      nil
    end
  end
end

Yast::DnsServerUIClient.new.main
