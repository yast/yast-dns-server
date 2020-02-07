#! /usr/bin/env rspec

require_relative "test_helper"
require "dns-server/service_widget_helpers"

describe Y2DnsServer::ServiceWidgetHelpers do
  class Tester
    include Y2DnsServer::ServiceWidgetHelpers
  end

  subject { Tester.new }

  before do
    allow(Yast2::SystemService).to receive(:find).with("named").and_return(service)
  end

  describe "#service" do
    context "when service is available" do
      let(:service) { double("named").as_null_object }

      it "returns a service" do
        expect(subject.service).to be(service)
      end
    end

    context "when service is NOT available" do
      let(:service) { nil }

      it "returns nil" do
        expect(subject.service).to be_nil
      end
    end
  end

  describe "#service_widget" do
    let(:service) { double("named").as_null_object }

    it "creates a service widget for \"named\" service" do
      expect(CWM::ServiceWidget).to receive(:new).with(service)

      subject.service_widget
    end

    it "returns a CWM::ServiceWidget" do
      expect(subject.service_widget).to be_a(CWM::ServiceWidget)
    end
  end
end
