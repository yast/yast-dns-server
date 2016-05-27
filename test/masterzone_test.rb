#! /usr/bin/env rspec

require_relative "test_helper"
require "yast"
require "yast/rspec"

describe "DnsServerDialogMasterzoneInclude" do
  class CurrentZoneMock
    include Yast::I18n
    include Yast::UIShortcuts

    attr_accessor :current_zone
    def initialize
      Yast.include self, "dns-server/dialog-masterzone.rb"
      @current_zone = {}
    end
  end

  let(:empty_zone_options) do
    {}
  end

  let(:simple_zone_options) do
    {
      "options" => [
        { "key" => "allow-transfer", "value" => "{ 10.0.0.0; }" }
      ]
    }
  end

  let(:any_zone_options) do
    {
      "options" => [
        { "key" => "allow-transfer", "value" => "{ any; }" }
      ]
    }
  end

  let(:none_zone_options) do
    {
      "options" => [
        { "key" => "allow-transfer", "value" => "{ none; }" }
      ]
    }
  end

  describe "#current_zone_allow_transfer" do
    it "parses a simple case" do
      z = CurrentZoneMock.new
      z.current_zone = simple_zone_options
      expect(z.current_zone_allow_transfer).to eq ["10.0.0.0"]
    end

    it "parses a 'none' case" do
      z = CurrentZoneMock.new
      z.current_zone = none_zone_options
      expect(z.current_zone_allow_transfer).to eq ["none"]
    end

    it "parses an 'any' case" do
      z = CurrentZoneMock.new
      z.current_zone = any_zone_options
      expect(z.current_zone_allow_transfer).to eq ["any"]
    end

    it "parses an empty case" do
      z = CurrentZoneMock.new
      z.current_zone = empty_zone_options
      expect(z.current_zone_allow_transfer).to eq []
    end
  end

  describe "#acl_names" do
    it "handles a simple case" do
      z = CurrentZoneMock.new
      z.current_zone = simple_zone_options
      expect(z.acl_names).to eq ["10.0.0.0", "any", "localhost", "localnets"]
    end

    it "handles an empty case" do
      z = CurrentZoneMock.new
      z.current_zone = empty_zone_options
      expect(z.acl_names).to eq ["any", "localhost", "localnets"]
    end

    it "omits 'none'" do
      z = CurrentZoneMock.new
      z.current_zone = none_zone_options
      expect(z.acl_names).to eq ["any", "localhost", "localnets"]
    end

    it "deduplicates 'any'" do
      z = CurrentZoneMock.new
      z.current_zone = any_zone_options
      expect(z.acl_names).to eq ["any", "localhost", "localnets"]
    end

    it "uses predeclared ACLs" do
      z = CurrentZoneMock.new
      expect(Yast::DnsServer).to receive(:GetAcl).and_return [
        "acl1 {10.1.0.1; 10.1.0.2;}",
        "acl2 {10.2.0.1; 10.2.0.2;}",
      ]
      expect(z.acl_names).to eq ["acl1", "acl2", "any", "localhost", "localnets"]
    end
  end

  describe "#ZoneAclInit" do
    it "sets up a simple case" do
      z = CurrentZoneMock.new
      z.current_zone = simple_zone_options

      expect(Yast::UI).to receive(:ChangeWidget)
        .with(Id("enable_zone_transport"), :Value, true)
      expect(Yast::UI).to receive(:ChangeWidget)
        .with(Id("acls_list"), :Enabled, true)
      expect(Yast::UI).to receive(:ChangeWidget)
        .with(Id("acls_list"), :SelectedItems, ["10.0.0.0"])
      expect { z.ZoneAclInit }.to_not raise_error
    end

    it "sets up a 'none' case" do
      z = CurrentZoneMock.new
      z.current_zone = none_zone_options

      expect(Yast::UI).to receive(:ChangeWidget)
        .with(Id("enable_zone_transport"), :Value, false)
      expect(Yast::UI).to receive(:ChangeWidget)
        .with(Id("acls_list"), :Enabled, false)
      expect { z.ZoneAclInit }.to_not raise_error
    end

    it "sets up an 'any' case" do
      z = CurrentZoneMock.new
      z.current_zone = any_zone_options

      expect(Yast::UI).to receive(:ChangeWidget)
        .with(Id("enable_zone_transport"), :Value, true)
      expect(Yast::UI).to receive(:ChangeWidget)
        .with(Id("acls_list"), :Enabled, true)
      expect(Yast::UI).to receive(:ChangeWidget)
        .with(Id("acls_list"), :SelectedItems, ["any"])
      expect { z.ZoneAclInit }.to_not raise_error
    end

    it "sets up an empty case" do
      z = CurrentZoneMock.new
      z.current_zone = empty_zone_options

      expect(Yast::UI).to receive(:ChangeWidget)
        .with(Id("enable_zone_transport"), :Value, true)
      expect(Yast::UI).to receive(:ChangeWidget)
        .with(Id("acls_list"), :Enabled, true)
      expect(Yast::UI).to receive(:ChangeWidget)
        .with(Id("acls_list"), :SelectedItems, ["any"])
      expect { z.ZoneAclInit }.to_not raise_error
    end
  end
end
