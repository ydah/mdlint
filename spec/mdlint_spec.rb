# frozen_string_literal: true

RSpec.describe Mdlint do
  it "has a version number" do
    expect(Mdlint::VERSION).not_to be_nil
  end

  describe ".format" do
    it "keeps front matter opaque while formatting the document" do
      input = "---\ntitle:  Hello\n---\n\n#  Heading\n"
      output = Mdlint.format(input)

      expect(output).to start_with("---\ntitle:  Hello\n---\n")
      expect(output).to include("# Heading\n")
    end

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

    it "wraps Japanese text by display width" do
      result = Mdlint.format("日本語の文章を折り返します。\n", wrap: 10)
      lines = result.split("\n").reject(&:empty?)

      expect(lines.all? { |line| Mdlint::TextWidth.measure(line) <= 10 }).to be true
    end

    it "keeps Japanese punctuation with natural line-break rules" do
      result = Mdlint.format("これは文章です。次の文章です。\n", wrap: 8)
      lines = result.split("\n").reject(&:empty?)

      expect(lines).not_to include(a_string_ending_with("「"))
      expect(lines.drop(1)).not_to include(a_string_starting_with("。"))
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

    it "is idempotent for ordinary Markdown" do
      input = "#  Title\n\nParagraph with **bold** and [link](https://example.com).\n"
      formatted = Mdlint.format(input)

      expect(Mdlint.format(formatted)).to eq(formatted)
    end

    it "formats GFM tables and task lists" do
      input = "| Name | State |\n|---|---|\n| A | ~~done~~ |\n\n- [x] Ready\n"

      result = Mdlint.format(input, dialect: :gfm)

      expect(result).to include("| Name | State    |\n| ---- | -------- |\n")
      expect(result).to include("- [x] Ready\n")
    end

    it "updates table-of-contents markers" do
      source = "# Title\n\n<!-- toc -->\nold\n<!-- toc -->\n\n## Details\n"

      result = Mdlint.format(source, toc: true)

      expect(result).to include("- [Title](#title)\n  - [Details](#details)")
      expect(result).not_to include("old")
    end
  end

  describe ".html" do
    it "renders headings, links, and inline formatting" do
      result = Mdlint.html("# Title\n\n**bold** [link](https://example.com)\n")

      expect(result).to include("<h1>Title</h1>")
      expect(result).to include("<strong>bold</strong>")
      expect(result).to include('<a href="https://example.com">link</a>')
    end

    it "renders balanced destinations, URI autolinks, and image alt text" do
      result = Mdlint.html("[link](foo(and(bar))) <irc://foo.bar:2233/baz>\n\n![foo *bar*](image.png)\n")

      expect(result).to include('<a href="foo(and(bar))">link</a>')
      expect(result).to include('<a href="irc://foo.bar:2233/baz">irc://foo.bar:2233/baz</a>')
      expect(result).to include('<img src="image.png" alt="foo bar" />')
    end

    it "renders GFM task lists and tables" do
      result = Mdlint.html("| Name | State |\n|---|---|\n| A | ~~done~~ |\n\n- [x] Ready\n", dialect: :gfm)

      expect(result).to include("<table>")
      expect(result).to include("<del>done</del>")
      expect(result).to include('type="checkbox" disabled checked')
    end

    it "renders GitHub alert blockquotes as alert asides" do
      result = Mdlint.html("> [!WARNING]\n> Be careful.\n")

      expect(result).to include('<aside class="markdown-alert markdown-alert-warning">')
      expect(result).to include("<p>Be careful.</p>")
    end

    it "renders supported directives as semantic HTML" do
      result = Mdlint.html(":::message Hello\nContent\n:::\n")

      expect(result).to include('<aside class="markdown-directive markdown-directive-message">')
      expect(result).to include('<p class="markdown-directive-title">Hello</p>')
      expect(result).to include("<p>Content</p>")
    end

    it "renders nested directives without closing the outer block early" do
      result = Mdlint.html(":::note Outer\n:::tip Inner\nContent\n:::\nAfter\n:::\n")

      expect(result.scan('class="markdown-directive markdown-directive-').length).to eq(2)
      expect(result).to include("After")
    end

    it "preserves rendered meaning through formatting" do
      input = "#  Title\n\nParagraph with **bold** and [link](https://example.com).\n"

      expect(Mdlint.html(input)).to eq(Mdlint.html(Mdlint.format(input)))
    end

    it "preserves footnotes and math" do
      input = "# Formula\n\nA note[^one] and $x^2$.\n\n[^one]: Footnote\n\n$$\nx^2\n$$\n"

      formatted = Mdlint.format(input)

      expect(formatted).to include("[^one]: Footnote")
      expect(formatted).to include("$$\nx^2\n$$")
      expect(Mdlint.html(formatted)).to include("fn-one", "math-block", "math-inline")
    end

    it "renders entities and reference links with decoded attributes" do
      source = <<~MARKDOWN
        [foo]

        [foo]: /f&ouml;&ouml; "f&ouml;&ouml;"
      MARKDOWN

      expect(Mdlint.html(source)).to include('<a href="/f%C3%B6%C3%B6" title="föö">foo</a>')
      expect(Mdlint.html("&nbsp; &copy; &#35;\n")).to include("  © #")
    end

    it "preserves tabs inside indented code content" do
      expect(Mdlint.html("    a\ta\n")).to eq("<pre><code>a\ta\n</code></pre>\n")
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

  describe ".fix" do
    it "returns formatted source instead of parser tokens" do
      result = Mdlint.fix("Line \n")

      expect(result).to eq("Line\n")
    end
  end
end
