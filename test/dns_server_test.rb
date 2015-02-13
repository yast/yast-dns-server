#! /usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "DnsServer"

describe "#GetLocalForwarder" do

  it "returns default forwarder if it's not initalized" do
    expect(Yast::DnsServer.GetLocalForwarder).to eq "resolver"
  end

  it "returns default forwarder if it's reset to default (blank entry)" do
    Yast::DnsServer.SetLocalForwarder("")
    expect(Yast::DnsServer.GetLocalForwarder).to eq "resolver"
  end

  it "returns given forwarder if it's previously set" do
    new_forwarder = "whichever-forwarder"
    Yast::DnsServer.SetLocalForwarder(new_forwarder)
    expect(Yast::DnsServer.GetLocalForwarder).to eq new_forwarder
  end

end

describe "#SetLocalForwarder" do

  it "does not set new forwarder if the forwarder is undefined" do
    expect(Yast::DnsServer.SetLocalForwarder(nil)).to eq false
  end

  it "sets new local forwarder if it's defined" do
    expect(Yast::DnsServer.SetLocalForwarder("")).to eq true
    expect(Yast::DnsServer.SetLocalForwarder("new_forwarder")).to eq true
  end

end
