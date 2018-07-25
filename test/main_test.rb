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
    context "when the named service is running" do
      context "and the config is marked to be reloaded" do
        it "reloads the service" do
          m = CurrentDialogMain.new
          expect(Yast::DnsServer).to receive(:Write).and_return true
          expect(m.service).to receive(:running?).and_return true
          expect(m.status_widget).to receive(:reload_flag?).and_return true
          expect(m.service).to receive(:reload)
          expect(m.WriteDialog ).to eq(:next)
        end
      end

      context "and the config is not marked to be reloaded" do
        it "does not restart nor reload the service" do
          m = CurrentDialogMain.new
          expect(Yast::DnsServer).to receive(:Write).and_return true
          expect(m.service).to receive(:running?).and_return true
          expect(m.status_widget).to receive(:reload_flag?).and_return false
          expect(m.service).to_not receive(:reload)
          expect(m.service).to_not receive(:restart)
          expect(m.WriteDialog ).to eq(:next)
        end
      end
    end

    context "when the named service is not running" do
      let(:m) { CurrentDialogMain.new }
      before do
        allow(m.status_widget).to receive(:reload_flag?).and_return true
      end

      it "does not restart nor reload the service" do
        expect(Yast::DnsServer).to receive(:Write).and_return true
        expect(m.service).to receive(:running?).and_return false
        expect(m.service).to_not receive(:restart)
        expect(m.service).to_not receive(:reload)
        expect(m.WriteDialog ).to eq(:next)
      end
    end
  end

end
