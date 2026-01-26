# frozen_string_literal: true

require "mdlint"

RSpec.describe Mdlint::Renderer do
  describe ".render" do
    it "renders reference links as inline links" do
      input = "[link][ref]\n\n[ref]: https://example.com\n"
      expected = "[link](https://example.com)\n"

      expect(Mdlint.format(input).rstrip + "\n").to eq(expected)
    end

    it "keeps unresolved reference links as plain text" do
      input = "[link][missing]\n"
      expected = "[link]\n"

      expect(Mdlint.format(input).rstrip + "\n").to eq(expected)
    end

    it "wraps link URLs containing parentheses in angle brackets" do
      input = "[link][ref]\n\n[ref]: https://example.com/a(b)\n"
      expected = "[link](<https://example.com/a(b)>)\n"

      expect(Mdlint.format(input).rstrip + "\n").to eq(expected)
    end

    it "uses longer fences when code contains backticks" do
      input = "```\ncode ```\n```\n"
      expected = "````\ncode ```\n````\n"

      expect(Mdlint.format(input).rstrip + "\n").to eq(expected)
    end

    it "renders blockquotes with nested headings" do
      input = "> # Title\n"
      expected = "> # Title\n"

      expect(Mdlint.format(input).rstrip + "\n").to eq(expected)
    end

    it "renders ordered lists using the start number by default" do
      input = "3. Three\n4. Four\n"
      expected = "3. Three\n3. Four\n"

      expect(Mdlint.format(input).rstrip + "\n").to eq(expected)
    end

    it "renders nested bullet lists with alternating markers" do
      input = "- Item\n  - Nested\n"
      output = Mdlint.format(input)

      expect(output).to include("- Item")
      expect(output).to include("- Nested")
    end

    it "wraps paragraphs at a specified width across multiple paragraphs" do
      input = "This is a long line that should wrap.\n\nSecond paragraph here.\n"
      output = Mdlint.format(input, wrap: 10)
      paragraphs = output.split("\n\n")

      expect(paragraphs.first.split("\n").all? { |l| l.length <= 10 }).to be true
      expect(paragraphs.last.split("\n").all? { |l| l.length <= 10 }).to be true
    end

    it "renders hardbreaks as backslash newlines" do
      input = "Line  \nNext\n"

      expect(Mdlint.format(input)).to include("\\\n")
    end

    it "renders inline HTML tags as-is" do
      input = "<span>text</span>\n"
      expected = "<span>text</span>\n"

      expect(Mdlint.format(input).rstrip + "\n").to eq(expected)
    end

    it "preserves HTML blocks" do
      input = "<div>\n</div>\n\n"
      expected = "<div>\n</div>\n"

      expect(Mdlint.format(input).rstrip + "\n").to eq(expected)
    end
  end
end
