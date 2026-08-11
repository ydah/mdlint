# frozen_string_literal: true

require "tmpdir"

RSpec.describe Mdlint::ParallelRunner do
  it "preserves input order while processing work concurrently" do
    result = described_class.map([1, 2, 3, 4], jobs: 2) { |value| value * 2 }

    expect(result).to eq([2, 4, 6, 8])
  end
end

RSpec.describe Mdlint::CacheStore do
  it "persists diagnostics and changes keys when options change" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "cache.json")
      violation = Mdlint::Linter::Violation.new(rule_id: "MD001", message: "jump", line: 2)
      first = described_class.new(path)
      key = first.key("# H\n### Jump\n", rules: ["MD001"])
      first.store(key, [violation])
      first.save

      second = described_class.new(path)

      expect(second.fetch(key).first.to_h).to eq(violation.to_h)
      expect(second.key("# H\n### Jump\n", rules: ["MD009"])).not_to eq(key)
    end
  end
end
