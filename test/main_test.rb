#! /usr/bin/env rspec

require_relative "test_helper"
require "yast"
require "yast/rspec"

describe "DnsServerDialogMainInclude" do
  class CurrentDialogMain
    include Yast::I18n
    include Yast::UIShortcuts

    attr_accessor :status_widget
    attr_accessor :service
    def initialize
      Yast.include self, "dns-server/dialog-main.rb"
      @status_widget = "status_widget"
      @service = "named.service"
    end
  end

  before do
    allow_any_instance_of(CurrentDialogMain).to receive(:fun_ref)
  end

  describe "#WriteDialog" do
    it "reloads running named.service" do
      m = CurrentDialogMain.new
      expect(Yast::DnsServer).to receive(:Write).and_return true
      expect(m.service).to receive(:running?).and_return true
      expect(m.status_widget).to receive(:reload_flag?).and_return true
      expect(m.service).to receive(:reload)
      expect(m.WriteDialog ).to eq(:next)
    end

    it "restarts not running named.service" do
      m = CurrentDialogMain.new
      expect(Yast::DnsServer).to receive(:Write).and_return true
      expect(m.service).to receive(:running?).and_return false
      expect(m.status_widget).to receive(:reload_flag?).and_return true
      expect(m.service).to receive(:restart)
      expect(m.WriteDialog ).to eq(:next)
    end
  end

end
