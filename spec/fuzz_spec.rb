# frozen_string_literal: true

RSpec.describe "parser robustness" do
  it "does not raise for deterministic arbitrary Markdown input" do
    random = Random.new(12_345)
    alphabet = "#*_-[]()<>`~$\\|:\n abcXYZ012"

    200.times do
      length = random.rand(0..160)
      source = Array.new(length) { alphabet[random.rand(alphabet.length)] }.join

      expect { Mdlint.parse(source) }.not_to raise_error
      expect { Mdlint.format(source) }.not_to raise_error
      expect { Mdlint.html(source) }.not_to raise_error
    end
  end
end
