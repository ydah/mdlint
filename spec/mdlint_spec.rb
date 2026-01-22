# frozen_string_literal: true

RSpec.describe Mdlint do
  it "has a version number" do
    expect(Mdlint::VERSION).not_to be_nil
  end

  describe ".format" do
    it "formats ATX headings" do
      input = "#   Title  \n"
      expected = "# Title\n"
      expect(Mdlint.format(input).rstrip + "\n").to eq(expected)
    end

    it "formats paragraphs" do
      input = "Hello world\n"
      expected = "Hello world\n"
      expect(Mdlint.format(input).rstrip + "\n").to eq(expected)
    end

    it "formats bullet lists with hyphen marker (mdformat style)" do
      input = "*  Item 1\n*  Item 2\n"
      expected = "- Item 1\n- Item 2\n"
      expect(Mdlint.format(input).rstrip + "\n").to eq(expected)
    end

    it "formats ordered lists with consistent numbering (mdformat style)" do
      input = "1.  First\n2.  Second\n"
      expected = "1. First\n1. Second\n"
      expect(Mdlint.format(input).rstrip + "\n").to eq(expected)
    end

    it "formats fenced code blocks" do
      input = "```ruby\nputs 'hello'\n```\n"
      expected = "```ruby\nputs 'hello'\n```\n"
      expect(Mdlint.format(input).rstrip + "\n").to eq(expected)
    end

    it "formats blockquotes" do
      input = "> Quote\n"
      expected = "> Quote\n"
      expect(Mdlint.format(input).rstrip + "\n").to eq(expected)
    end

    it "formats horizontal rules with 70 underscores (mdformat style)" do
      input = "---\n"
      expected = "#{"_" * 70}\n"
      expect(Mdlint.format(input).rstrip + "\n").to eq(expected)
    end

    it "converts indented code blocks to fenced code blocks (mdformat style)" do
      input = "    code line\n"
      expected = "```\ncode line\n```\n"
      expect(Mdlint.format(input).rstrip + "\n").to eq(expected)
    end

    it "converts reference links to inline links (mdformat style)" do
      input = "[link][ref]\n\n[ref]: https://example.com\n"
      result = Mdlint.format(input)
      expect(result).to include("[link](https://example.com)")
    end

    it "uses consecutive numbering when number option is set" do
      input = "1. First\n2. Second\n"
      result = Mdlint.format(input, number: true)
      expect(result).to include("1. First")
      expect(result).to include("2. Second")
    end

    it "wraps text at specified width" do
      input = "This is a long line that should be wrapped at a specific width for better readability.\n"
      result = Mdlint.format(input, wrap: 40)
      lines = result.split("\n").reject(&:empty?)
      expect(lines.all? { |l| l.length <= 40 }).to be true
    end

    it "removes line breaks with wrap: :no option" do
      input = "Line one\nLine two\n"
      result = Mdlint.format(input, wrap: :no)
      expect(result.strip).to eq("Line one Line two")
    end

    it "uses CRLF line endings when end_of_line is :crlf" do
      input = "Hello\nWorld\n"
      result = Mdlint.format(input, end_of_line: :crlf)
      expect(result).to include("\r\n")
    end
  end

  describe ".parse" do
    it "returns tokens for headings" do
      tokens = Mdlint.parse("# Title\n")
      expect(tokens.first.type).to eq(:heading_open)
    end

    it "returns tokens with inline children" do
      tokens = Mdlint.parse("# Title\n")
      inline_token = tokens.find { |t| t.type == :inline }
      expect(inline_token.children).not_to be_empty
    end
  end
end
