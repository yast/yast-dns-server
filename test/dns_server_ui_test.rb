#! /usr/bin/env rspec

require_relative "test_helper"

Yast.import "DnsServerUI"

describe Yast::DnsServerUI do
  subject { Yast::DnsServerUI }

  # Direct translation to RSpec of equivalent tests from the old testsuite
  describe "#ChangeIPToLocalEquivalent" do
    it "transforms private IPv4 addresses" do
      expect(subject.ChangeIPToLocalEquivalent("192.168.5.1")).to eq "127.0.0.1"
    end

    it "transforms public IPv4 addresses" do
      expect(subject.ChangeIPToLocalEquivalent("238.11.26.25")).to eq "127.0.0.1"
    end

    it "transforms IPv6 addresses" do
      expect(subject.ChangeIPToLocalEquivalent("fe80::21c:c0ff:fe18:f01c")).to eq "::1"
    end

    it "returns nil for invalid IPs" do
      expect(subject.ChangeIPToLocalEquivalent("trash")).to be_nil
    end
  end

  # Direct translation to RSpec of equivalent tests from the old testsuite
  describe "#CurrentlyUsedIPs" do
    before do
      allow(Yast::SCR).to receive(:Execute).and_return(
        "exit"   => 0,
        "stdout" => "127.0.0.1\n" +
          "127.0.0.2\n" +
          "::1\n" +
          "192.168.5.1\n" +
          "238.11.26.25\n" +
          "fe80::21c:c0ff:fe18:f01c",
        "stderr" => ""
      )
    end

    it "excludes local IPs when requested to do so" do
      expect(subject.CurrentlyUsedIPs(false)).to eq(
        ["192.168.5.1", "238.11.26.25", "fe80::21c:c0ff:fe18:f01c"]
      )
    end

    it "includes local IPs when requested to do so" do
      expect(subject.CurrentlyUsedIPs(true)).to eq(
        ["127.0.0.1", "127.0.0.2", "::1", "192.168.5.1", "238.11.26.25", "fe80::21c:c0ff:fe18:f01c"]
      )
    end
  end
end
