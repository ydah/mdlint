# frozen_string_literal: true

require "mdlint"

RSpec.describe Mdlint::Parser do
  describe ".parse" do
    it "preserves YAML front matter at the beginning of a document" do
      tokens = Mdlint.parse("---\ntitle: Hello\ntags: [a, b]\n---\n# Heading\n")
      front_matter = tokens.find { |t| t.type == :front_matter }

      expect(front_matter.content).to eq("---\ntitle: Hello\ntags: [a, b]\n---\n")
      expect(tokens.map(&:type)).to include(:heading_open)
    end

    it "does not treat a later delimiter as front matter" do
      tokens = Mdlint.parse("# Heading\n\n---\n")

      expect(tokens.none? { |t| t.type == :front_matter }).to be true
      expect(tokens.any? { |t| t.type == :hr }).to be true
    end

    it "preserves TOML and JSON front matter" do
      toml = Mdlint.parse("+++\ntitle = 'Hello'\n+++\n# Heading\n")
      json = Mdlint.parse(";;;\n{\"title\": \"Hello\"}\n;;;\n# Heading\n")

      expect(toml.find { |t| t.type == :front_matter }.meta[:format]).to eq(:toml)
      expect(json.find { |t| t.type == :front_matter }.meta[:format]).to eq(:json)
    end

    it "parses setext headings as heading tokens" do
      tokens = Mdlint.parse("\nTitle\n---\n")
      heading = tokens.find { |t| t.type == :heading_open }
      inline = tokens.find { |t| t.type == :inline }

      expect(heading.tag).to eq("h2")
      expect(heading.markup).to eq("-")
      expect(inline.content).to eq("Title")
    end

    it "parses a setext heading on the first line" do
      tokens = Mdlint.parse("Title\n---\n")

      expect(tokens.find { |t| t.type == :heading_open }.tag).to eq("h2")
    end

    it "parses ATX headings and trims closing hashes" do
      tokens = Mdlint.parse("# Title ###\n")
      inline = tokens.find { |t| t.type == :inline }

      expect(inline.content).to eq("Title")
    end

    it "parses HTML blocks" do
      tokens = Mdlint.parse("<div>\n</div>\n\n")
      html = tokens.find { |t| t.type == :html_block }

      expect(html.content).to eq("<div>\n</div>\n")
    end

    it "parses HTML comment blocks" do
      tokens = Mdlint.parse("<!-- comment -->\n\n")
      html = tokens.find { |t| t.type == :html_block }

      expect(html.content).to eq("<!-- comment -->\n")
    end

    it "parses reference definitions with title" do
      tokens = Mdlint.parse("[Ref]: https://example.com \"Title\"\n")
      ref = tokens.find { |t| t.type == :reference_definition }

      expect(ref.attrs[:label]).to eq("ref")
      expect(ref.attrs[:url]).to eq("https://example.com")
      expect(ref.attrs[:title]).to eq("Title")
    end

    it "parses reference definitions without title" do
      tokens = Mdlint.parse("[Ref]: <https://example.com>\n")
      ref = tokens.find { |t| t.type == :reference_definition }

      expect(ref.attrs[:label]).to eq("ref")
      expect(ref.attrs[:url]).to eq("https://example.com")
      expect(ref.attrs[:title]).to be_nil
    end

    it "parses blockquotes into nested tokens" do
      tokens = Mdlint.parse("> Quote\n")

      expect(tokens.map(&:type)).to include(:blockquote_open, :paragraph_open, :inline, :blockquote_close)
    end

    it "parses multi-line blockquotes" do
      tokens = Mdlint.parse("> Line 1\n> Line 2\n")
      inline = tokens.find { |t| t.type == :inline }

      expect(inline.content).to eq("Line 1\nLine 2")
    end

    it "parses bullet lists and list items" do
      tokens = Mdlint.parse("- Item 1\n- Item 2\n")

      expect(tokens.map(&:type)).to include(:bullet_list_open, :list_item_open, :paragraph_open, :list_item_close, :bullet_list_close)
    end

    it "parses ordered lists with start number and delimiter" do
      tokens = Mdlint.parse("2) Two\n3) Three\n")
      list = tokens.find { |t| t.type == :ordered_list_open }

      expect(list.attrs[:start]).to eq(2)
      expect(list.markup).to eq(")")
    end

    it "parses fenced code blocks with info string" do
      tokens = Mdlint.parse("```ruby\nputs 1\n```\n")
      fence = tokens.find { |t| t.type == :fence }

      expect(fence.info).to eq("ruby")
      expect(fence.content).to eq("puts 1\n")
    end

    it "parses indented code blocks" do
      tokens = Mdlint.parse("    code\n    more\n")
      block = tokens.find { |t| t.type == :code_block }

      expect(block.content).to eq("code\nmore\n")
    end

    it "parses horizontal rules" do
      tokens = Mdlint.parse("---\n")
      hr = tokens.find { |t| t.type == :hr }

      expect(hr.markup).to eq("-")
    end

    it "parses inline elements into children tokens" do
      tokens = Mdlint.parse("This is **bold** and *em* with ` code `.\n")
      inline = tokens.find { |t| t.type == :inline }
      types = inline.children.map(&:type)
      code_token = inline.children.find { |t| t.type == :code_inline }

      expect(types).to include(:strong_open, :strong_close, :em_open, :em_close)
      expect(code_token.content).to eq("code")
    end

    it "parses links, images, and autolinks" do
      tokens = Mdlint.parse("![alt](img.png \"Title\") [text](https://example.com) <https://example.com>\n")
      inline = tokens.find { |t| t.type == :inline }
      image = inline.children.find { |t| t.type == :image }
      autolink = inline.children.find { |t| t.type == :link_open && t.markup == "autolink" }

      expect(image.attrs[:alt]).to eq("alt")
      expect(image.attrs[:src]).to eq("img.png")
      expect(image.attrs[:title]).to eq("Title")
      expect(autolink.attrs[:href]).to eq("https://example.com")
    end

    it "parses softbreaks, hardbreaks, and escapes" do
      tokens = Mdlint.parse("Line  \nNext\n\\*\n")
      inline = tokens.find { |t| t.type == :inline }
      types = inline.children.map(&:type)
      text_tokens = inline.children.select { |t| t.type == :text }.map(&:content)

      expect(types).to include(:hardbreak, :softbreak)
      expect(text_tokens).to include("*")
    end

    it "parses GFM tables, task lists, and strikethrough" do
      source = "| Name | State |\n| --- | --- |\n| A | ~~done~~ |\n\n- [x] Ready\n\n~~strike~~\n"
      tokens = Mdlint.parse(source, dialect: :gfm)
      table = tokens.find { |token| token.type == :table }
      task = tokens.find { |token| token.type == :list_item_open }
      inline = tokens.find { |token| token.type == :inline && token.content.include?("~~") }

      expect(table.meta[:rows].length).to eq(2)
      expect(task.attrs).to include(task: true, checked: true)
      expect(inline.children.map(&:type)).to include(:s_open, :s_close)
    end

    it "preserves footnotes and math tokens" do
      tokens = Mdlint.parse("A note[^one] and $x^2$.\n\n[^one]: Footnote\n\n$$\nx^2\n$$\n")

      expect(tokens.map(&:type)).to include(:footnote_definition, :math_block)
      inline = tokens.find { |token| token.type == :inline }
      expect(inline.children.map(&:type)).to include(:footnote_ref, :math_inline)
    end

    it "preserves MDX component blocks" do
      tokens = Mdlint.parse("<Alert type=\"warning\">\nContent\n</Alert>\n")

      expect(tokens.map(&:type)).to eq([:html_block])
      expect(tokens.first.content).to include("</Alert>")
    end

    it "records GitHub alert metadata on blockquotes" do
      token = Mdlint.parse("> [!NOTE]\n> Content\n").find { |candidate| candidate.type == :blockquote_open }

      expect(token.attrs[:alert]).to eq("note")
    end
  end
end
