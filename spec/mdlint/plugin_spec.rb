# frozen_string_literal: true

RSpec.describe Mdlint::Plugin do
  it "registers a dialect with selected Markdown features" do
    described_class.register_dialect(:docs, features: [:tables])

    expect(Mdlint::Dialect.resolve(:docs).feature?(:tables)).to be true
    expect(Mdlint::Dialect.resolve(:docs).feature?(:strikethrough)).to be false
  end

  it "loads custom rules through the stable registration API" do
    rule = Class.new(Mdlint::Linter::Rule) do
      self.rule_id = "PL001"
      self.aliases = ["plugin-rule"]
      self.description = "Plugin rule"

      def check(_tokens, _source)
        add_violation(message: "plugin", line: 1)
        @violations
      end
    end

    begin
      described_class.register_rule(rule)

      expect(Mdlint::Linter::RuleRegistry.find("plugin-rule")).to eq(rule)
      expect(Mdlint.lint("# Heading\n", rules: ["PL001"]).map(&:rule_id)).to eq(["PL001"])
    ensure
      described_class.unregister_rule(rule)
    end
  end
end
