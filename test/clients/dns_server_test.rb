#!/usr/bin/env rspec

require_relative "../test_helper"
require "dns-server/clients/dns_server"

describe Yast::DnsServerClient do
  subject(:client) { Yast::DnsServerClient.new }

  let(:dns_server_ui) { double("dns_server_ui").as_null_object }
  let(:packages) { Yast::DnsServer.AutoPackages["install"] }

  before do
    allow(Yast).to receive(:import).with("DnsServerUI")
    allow(dns_server_ui).to receive(:DnsSequence).and_return(:next)
    stub_const("Yast::DnsServerUI", dns_server_ui)
  end

  describe "#main" do
    it "runs DnsSequence and returns its value" do
     allow(Yast::PackageSystem).to receive(:CheckAndInstallPackages).and_return(true)
     expect(dns_server_ui).to receive(:DnsSequence).and_return(:next)
     expect(client.main).to eq(:next)
    end

    it "makes sure that 'bind' package is installed" do
      expect(Yast::PackageSystem).to receive(:CheckAndInstallPackages)
        .with(packages).and_return(true)
      client.main
    end

    context "if the user refuses to install the package" do
      it "shows and error an quits" do
        expect(Yast::PackageSystem).to receive(:CheckAndInstallPackages)
          .with(packages).and_return(false)
        expect(Yast).to_not receive(:Import).with("DnsServerUI")
        expect(Yast::Popup).to receive(:Error)
        expect(client.main).to eq(:abort)
      end
    end
  end
end
