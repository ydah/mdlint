# frozen_string_literal: true

require "json"

RSpec.describe "CommonMark compatibility fixtures" do
  fixture_path = ENV["COMMONMARK_SPEC_PATH"] || File.expand_path("fixtures/commonmark_smoke.json", __dir__)
  fixtures = JSON.parse(File.read(fixture_path))

  fixtures.each do |fixture|
    it "renders #{fixture.fetch("example")}" do
      expect(Mdlint.html(fixture.fetch("markdown"))).to eq(fixture.fetch("html"))
    end
  end
end
