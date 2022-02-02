#! /usr/bin/env rspec

require_relative "test_helper"

class DnsServerCmdlineDummy < Yast::Module
  def initialize
    Yast.include self, "dns-server/cmdline.rb"
  end
end


describe "Yast::DnsServerCmdlineInclude" do
  subject { DnsServerCmdlineDummy.new }

  it "loads" do
    expect { subject }.to_not raise_error
  end
end
