# frozen_string_literal: true

require "mdlint/cli"
require "json"

RSpec.describe Mdlint::CLI::OutputFormatter do
  it "emits reviewdog RDJSON diagnostics" do
    violation = Mdlint::Linter::Violation.new(
      rule_id: "MD001",
      message: "Heading jumped",
      line: 4,
      column: 3,
      severity: :error
    )

    result = JSON.parse(described_class.new("reviewdog").render([{ filename: "README.md", violation: violation }]))

    expect(result.fetch("source").fetch("name")).to eq("mdlint")
    diagnostic = result.fetch("diagnostics").first
    expect(diagnostic.fetch("location").fetch("path")).to eq("README.md")
    expect(diagnostic.fetch("location").fetch("range").fetch("start")).to include("line" => 4, "column" => 3)
    expect(diagnostic.fetch("severity")).to eq("ERROR")
  end
end
