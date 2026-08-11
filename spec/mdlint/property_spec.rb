# frozen_string_literal: true

RSpec.describe "Markdown formatting properties" do
  def generated_document(seed)
    random = Random.new(seed)
    heading = ["# Title", "## Section", "### Detail"].sample(random: random)
    paragraph = [
      "A short paragraph with **bold** and `code`.",
      "A [link](https://example.com) and plain text.",
      "A second line with *emphasis* and punctuation."
    ].sample(random: random)
    list = ["- one\n- two", "1. first\n2. second"].sample(random: random)
    block = ["```text\nvalue\n```", "> quoted text"].sample(random: random)

    [heading, paragraph, list, block].shuffle(random: random).join("\n\n") + "\n"
  end

  50.times do |seed|
    it "is idempotent for generated document #{seed}" do
      source = generated_document(seed)
      formatted = Mdlint.format(source)

      expect(Mdlint.format(formatted)).to eq(formatted)
    end

    it "preserves HTML meaning for generated document #{seed}" do
      source = generated_document(seed)
      expect(Mdlint.html(source)).to eq(Mdlint.html(Mdlint.format(source)))
    end
  end
end
