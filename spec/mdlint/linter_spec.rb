# frozen_string_literal: true

RSpec.describe Mdlint::Linter do
  describe ".check" do
    it "detects heading level increment violations" do
      source = "# Heading 1\n\n### Heading 3\n"
      violations = Mdlint.lint(source)

      expect(violations.map(&:rule_id)).to include("MD001")
    end

    it "detects multiple consecutive blank lines" do
      source = "# Heading\n\n\n\nParagraph\n"
      violations = Mdlint.lint(source)

      expect(violations.map(&:rule_id)).to include("MD012")
    end

    it "detects first line not being heading" do
      source = "Some paragraph\n\n# Heading\n"
      violations = Mdlint.lint(source)

      expect(violations.map(&:rule_id)).to include("MD041")
    end

    it "returns no violations for valid markdown" do
      source = "# Heading 1\n\n## Heading 2\n\nParagraph\n"
      violations = Mdlint.lint(source)

      md001_violations = violations.select { |v| v.rule_id == "MD001" }
      expect(md001_violations).to be_empty
    end
  end

  describe "rule disabling" do
    it "can disable specific rules" do
      source = "# Heading 1\n\n### Heading 3\n"
      violations = Mdlint.lint(source, disable: ["MD001"])

      expect(violations.map(&:rule_id)).not_to include("MD001")
    end
  end
end

RSpec.describe Mdlint::Linter::Violation do
  describe "#to_s" do
    it "formats violation as string" do
      violation = described_class.new(
        rule_id: "MD001",
        message: "Test message",
        line: 5,
        column: 10
      )

      expect(violation.to_s).to eq("[MD001] 5:10: Test message")
    end

    it "formats without column" do
      violation = described_class.new(
        rule_id: "MD001",
        message: "Test message",
        line: 5
      )

      expect(violation.to_s).to eq("[MD001] 5: Test message")
    end
  end
end
