#! /usr/bin/env rspec

require_relative "test_helper"

require "yast2/system_service"
require "dns-server/service_widget_helpers"

Yast.import "DnsServerUI"

describe "DnsServerDialogMainInclude" do
  subject(:main_dialog) { CurrentDialogMain.new }

  class CurrentDialogMain
    include Yast::I18n
    include Yast::UIShortcuts
    include Y2DnsServer::ServiceWidgetHelpers

    def initialize
      Yast.include self, "dns-server/dialog-main.rb"
    end

    def fun_ref(*args)
    end
  end

  let(:auto) { false }

  before do
    allow(Yast::Mode).to receive(:auto).and_return(auto)
    allow_any_instance_of(CurrentDialogMain).to receive(:fun_ref)
  end

  describe "#WriteDialog" do
    before do
      allow(Yast::DnsServer).to receive(:Write).and_return(dns_configuration_written)
      allow(Yast2::SystemService).to receive(:find).and_return(service)

      allow(service).to receive(:currently_active?).and_return(active)
    end

    let(:service) { instance_double(Yast2::SystemService, save: true, refresh: true) }
    let(:dns_configuration_written) { true }
    let(:active) { true }

    context "when DNS configuration is written" do
      it "saves the system service" do
        expect(service).to receive(:save)

        main_dialog.WriteDialog
      end

      it "returns :next" do
        expect(main_dialog.WriteDialog).to eq(:next)
      end


      context "and the local forwarder is \"bind\"" do
        before do
          allow(Yast2::Popup).to receive(:show)
          allow(Yast::DnsServer).to receive(:GetLocalForwarder).and_return("bind")
        end

        context "but service is stopped" do
          let(:active) { false }

          it "resets the local forwarder" do
            expect(Yast::DnsServer).to receive(:SetLocalForwarder).with("resolver")

            main_dialog.WriteDialog
          end
        end

        context "but service is running" do
          let(:active) { true }

          it "does not reset the local forwarder" do
            expect(Yast::DnsServer).to_not receive(:SetLocalForwarder)

            main_dialog.WriteDialog
          end
        end
      end

      context "and the local forwarder is not \"bind\"" do
        before do
          allow(Yast::DnsServer).to receive(:GetLocalForwarder).and_return("whatever")
        end

        it "does not reset the local forwarder" do
          expect(Yast::DnsServer).to_not receive(:SetLocalForwarder)

          main_dialog.WriteDialog
        end
      end

      context "in auto mode" do
        let(:auto) { true }

        it "keeps the server status" do
          expect(service).to receive(:save).with(hash_including(keep_state: true))

          main_dialog.WriteDialog
        end
      end
    end

    context "when the configuration is not written" do
      before do
        allow(Yast2::Popup).to receive(:show).and_return(change_settings)
      end

      let(:change_settings) { :yes }
      let(:dns_configuration_written) { false }

      it "asks for changing the current settings" do
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
