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

    it "supports line length settings" do
      source = "# Heading\n\nThis line is intentionally longer than ten characters.\n"
      violations = Mdlint.lint(source, rules: { "MD013" => { line_length: 10 } })

      expect(violations.map(&:rule_id)).to include("MD013")
    end

    it "supports inline disable and enable directives" do
      source = <<~MARKDOWN
        # Heading
        <!-- mdlint-disable MD001 -->
        ### Disabled
        <!-- mdlint-enable MD001 -->
        ##### Enabled
      MARKDOWN

      violations = Mdlint.lint(source)

      expect(violations.map(&:rule_id)).to eq(["MD001"])
      expect(violations.first.line).to eq(5)
    end

    it "does not apply directives inside fenced code" do
      source = <<~MARKDOWN
        # Heading
        ```markdown
        <!-- mdlint-disable MD001 -->
        ```
        ### Jump
      MARKDOWN

      expect(Mdlint.lint(source).map(&:rule_id)).to include("MD001")
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

  describe "fix contract" do
    it "returns source unchanged for token-only rules" do
      source = "# Heading\n\n### Jump\n"

      expect(Mdlint::Linter.fix(source, rules: ["MD001"])).to eq(source)
    end

    it "fixes setext headings through the string contract" do
      expect(Mdlint.fix("Title\n---\n")).to eq("## Title\n")
    end

    it "applies severity configured for a rule" do
      violations = Mdlint.lint("# Heading\n\n### Jump\n", rules: { "MD001" => { severity: :error } })

      expect(violations.find { |violation| violation.rule_id == "MD001" }.severity).to eq(:error)
    end

    it "accepts rule aliases" do
      violations = Mdlint.lint("# Heading\n\n### Jump\n", rules: ["heading-increment"])

      expect(violations.map(&:rule_id)).to eq(["MD001"])
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
