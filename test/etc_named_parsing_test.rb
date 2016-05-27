#! /usr/bin/env rspec

require_relative "test_helper"
require "yast"
require "yast/rspec"
require "json"

describe ".dns.named agent" do
  dirs = Dir.glob(File.join(File.dirname(__FILE__), "data", "*"))
  dirs.each do |dir|
    basename = File.basename(dir)
    it "parses '#{basename}'" do
      # 1) Use the YaST agent to parse a text file to a nested hash structure
      actual = nil
      change_scr_root(dir) do
        actual = Yast::SCR.Read(Yast::Path.new(".dns.named.all"))
      end

      # 2) Read a JSON file representing the expected structure.
      # (Why json? It is Structured and Simple (which YAML is not))
      expected_json = File.read("#{dir}/etc/named.conf.json")

      # 3a) We could compare the hashes, but in case of a mismatch
      # RSpec makes it hard to see where the difference is...

      # expected = JSON.parse(expected_json)
      # expect(actual).to eq(expected)

      # 3b)... So we compare the textual JSONs instead. The diff is much nicer.
      actual_json = JSON.pretty_generate(actual)
      if ENV["WRITE_ACTUAL_JSON"] # enable when developing a new test
        File.write("#{dir}/etc/named.conf.actual.json", actual_json)
      end
      expect(actual_json).to eq(expected_json)
    end
  end
end
