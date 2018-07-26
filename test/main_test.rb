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
    let(:m) { CurrentDialogMain.new }
    let(:written) { false }
    let(:running) { true }

    before do
      allow(Yast::DnsServer).to receive(:Write).and_return written
      allow(m.service).to receive(:running?).and_return running
    end

    it "writes the DNS configuration" do
      expect(Yast::DnsServer).to receive(:Write).and_return written
      m.WriteDialog
    end

    context "when the configuration is written" do
      let(:written) { true }

      context "and the named service is running" do
        context "and the config is marked to be reloaded" do
          it "reloads the service" do
            expect(m.status_widget).to receive(:reload_flag?).and_return true
            expect(m.service).to receive(:reload)
            expect(m.WriteDialog ).to eq(:next)
          end
        end

        context "and the config is not marked to be reloaded" do
          it "does not restart nor reload the service" do
            expect(m.status_widget).to receive(:reload_flag?).and_return false
            expect(m.service).to_not receive(:reload)
            expect(m.service).to_not receive(:restart)
            expect(m.WriteDialog ).to eq(:next)
          end
        end
      end

      context "and the named service is not running" do
        let(:running) { false}

        before do
          allow(m.status_widget).to receive(:reload_flag?).and_return true
        end

        it "does not restart nor reload the service" do
          expect(m.service).to_not receive(:restart)
          expect(m.service).to_not receive(:reload)
          expect(m.WriteDialog ).to eq(:next)
        end
      end
    end

    context "when the configuration is not written" do
      let(:written) { false }

      it "aks for changing the current settings" do
        expect(Yast::Popup).to receive(:YesNo)
        m.WriteDialog
      end

      it "returns :back if decided to change the current settings" do
        expect(Yast::Popup).to receive(:YesNo).and_return true
        expect(m.WriteDialog).to eq(:back)
      end

      it "returns :abort if canceled" do
        expect(Yast::Popup).to receive(:YesNo).and_return false
        expect(m.WriteDialog).to eq(:abort)
      end
    end
  end

end
