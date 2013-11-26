#! /usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "DnsServer"

describe "#GetLocalForwarder" do
  it "returns default forwarder if not initalized" do
    expect(Yast::DnsServer.GetLocalForwarder).to eq "resolver"
  end

  it "returns default forwarder if it's reset to default (blank entry)" do
    Yast::DnsServer.SetLocalForwarder("")
    expect(Yast::DnsServer.GetLocalForwarder).to eq "resolver"
  end

  it "returns given forwarder if previously set" do
    new_forwarder = "whichever-forwarder"
    Yast::DnsServer.SetLocalForwarder(new_forwarder)
    expect(Yast::DnsServer.GetLocalForwarder).to eq new_forwarder
  end
end

describe "#SetLocalForwarder" do
  it "does not set new forwarder if not defined" do
    expect(Yast::DnsServer.SetLocalForwarder(nil)).to be_false
  end

  it "sets new local forwarder if defined" do
    expect(Yast::DnsServer.SetLocalForwarder("")).to be_true
    expect(Yast::DnsServer.SetLocalForwarder("new_forwarder")).to be_true
  end
end
