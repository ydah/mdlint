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

    it "detects setext heading style violations" do
      source = "\nTitle\n---\n"
      violations = Mdlint.lint(source)

      expect(violations.map(&:rule_id)).to include("MD003")
    end

    it "detects trailing spaces except hardbreaks" do
      source = "Line \nNext\n"
      violations = Mdlint.lint(source)

      expect(violations.map(&:rule_id)).to include("MD009")
    end

    it "allows hardbreak trailing spaces before another line" do
      source = "Line  \nNext\n"
      violations = Mdlint.lint(source)

      expect(violations.map(&:rule_id)).not_to include("MD009")
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

  describe "rule filtering" do
    it "only runs specified rules" do
      source = "# Heading 1\n\n### Heading 3\n\n\n"
      violations = Mdlint.lint(source, rules: ["MD001"])

      expect(violations.map(&:rule_id)).to contain_exactly("MD001")
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

RSpec.describe Mdlint::Linter::RuleRegistry do
  it "finds registered rules by id" do
    expect(described_class.find("MD001")).not_to be_nil
  end
end

RSpec.describe "Mdlint::Linter::Rules fix behavior" do
  it "fixes multiple consecutive blank lines" do
    rule = Mdlint::Linter::Rules::NoMultipleBlanks.new
    source = "# Heading\n\n\n\nParagraph\n"

    expect(rule.fix([], source)).to eq("# Heading\n\nParagraph\n")
  end

  it "removes trailing spaces but keeps hardbreaks" do
    rule = Mdlint::Linter::Rules::NoTrailingSpaces.new
    source = "Line  \nNext \n"

    expect(rule.fix([], source)).to eq("Line  \nNext\n")
  end
end
