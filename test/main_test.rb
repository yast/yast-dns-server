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
    subject { CurrentDialogMain.new }

    before do
      allow(Yast::DnsServer).to receive(:Write).and_return written
    end

    context "when the configuration is not written" do
      let(:written) { false }
      let(:change_settings) { :yes }

      before do
        allow(Yast2::Popup).to receive(:show).and_return(change_settings)
      end

      it "aks for changing the current settings" do
        expect(Yast2::Popup).to receive(:show).with(instance_of(String), hash_including(buttons: :yes_no))

        subject.WriteDialog
      end

      context "and user decides to change the current setting" do
        it "returns :back" do
          expect(subject.WriteDialog).to eq(:back)
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
