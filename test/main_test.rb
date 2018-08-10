#! /usr/bin/env rspec

require_relative "test_helper"
require_relative "../src/modules/DnsServerUI.rb"
require "dns-server/service_widget_helpers"

require "yast2/system_service"

describe "DnsServerDialogMainInclude" do
  class CurrentDialogMain
    include Yast::I18n
    include Yast::UIShortcuts
    include Y2DnsServer::ServiceWidgetHelpers

    def initialize
      Yast.include self, "dns-server/dialog-main.rb"
    end
  end

  before do
    allow_any_instance_of(CurrentDialogMain).to receive(:fun_ref)
  end

  describe "#WriteDialog" do
    subject(:main_dialog) { CurrentDialogMain.new }

    before do
      allow(Yast::DnsServer).to receive(:Write).and_return(dns_configuration_written)
      allow(Yast2::SystemService).to receive(:find).and_return(service)
    end

    let(:service) { instance_double(Yast2::SystemService, save: true) }
    let(:dns_configuration_written) { true }

    context "when DNS configuration is written" do
      it "saves the system service" do
        expect(service).to receive(:save)

        main_dialog.WriteDialog
      end

      it "returns :next" do
        expect(main_dialog.WriteDialog).to eq(:next)
      end
    end

    context "when the configuration is not written" do
      before do
        allow(Yast2::Popup).to receive(:show).and_return(change_settings)
      end

      let(:change_settings) { :yes }
      let(:dns_configuration_written) { false }

      it "aks for changing the current settings" do
        expect(Yast2::Popup).to receive(:show)
          .with(instance_of(String), hash_including(buttons: :yes_no))

        main_dialog.WriteDialog
      end

      context "and user decides to change the current setting" do
        it "returns :back" do
          expect(main_dialog.WriteDialog).to eq(:back)
        end
      end

      context "and user decides to cancel" do
        let(:change_settings) { :no }

        it "returns :abort" do
          expect(subject.WriteDialog).to eq(:abort)
        end
      end
    end
  end
end
