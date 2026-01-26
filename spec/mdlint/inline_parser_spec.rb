# frozen_string_literal: true

require "mdlint/parser/inline_parser"

RSpec.describe Mdlint::Parser::InlineParser do
  let(:parser) { described_class.new }

  it "parses escaped characters as text" do
    tokens = parser.parse("\\*")

    expect(tokens.length).to eq(1)
    expect(tokens.first.type).to eq(:text)
    expect(tokens.first.content).to eq("*")
  end

  it "parses strong and emphasis with asterisks and underscores" do
    tokens = parser.parse("**bold** __strong__ *em* _em_")
    types = tokens.map(&:type)

    expect(types).to include(:strong_open, :strong_close, :em_open, :em_close)
  end

  it "parses inline code and trims surrounding spaces" do
    tokens = parser.parse("` code `")
    code = tokens.find { |t| t.type == :code_inline }

    expect(code.content).to eq("code")
  end

  it "parses inline links with title" do
    tokens = parser.parse("[text](https://example.com \"Title\")")
    link_open = tokens.find { |t| t.type == :link_open }

    expect(link_open.attrs[:href]).to eq("https://example.com")
    expect(link_open.attrs[:title]).to eq("Title")
  end

  it "parses reference and shortcut reference links" do
    tokens = parser.parse("[text][ref] [shortcut]")
    reference_links = tokens.select { |t| t.type == :link_open && t.markup == "reference" }

    expect(reference_links.map { |t| t.attrs[:reference_label] }).to contain_exactly("ref", "shortcut")
  end

  it "parses images with title" do
    tokens = parser.parse("![alt](img.png \"Title\")")
    image = tokens.find { |t| t.type == :image }

    expect(image.attrs[:alt]).to eq("alt")
    expect(image.attrs[:src]).to eq("img.png")
    expect(image.attrs[:title]).to eq("Title")
  end

  it "parses autolinks and email autolinks" do
    tokens = parser.parse("<https://example.com> <user@example.com>")
    autolinks = tokens.select { |t| t.type == :link_open && t.markup == "autolink" }

    expect(autolinks.map { |t| t.attrs[:href] }).to contain_exactly("https://example.com", "mailto:user@example.com")
  end

  it "parses inline HTML tags" do
    tokens = parser.parse("<span>text</span>")
    html = tokens.find { |t| t.type == :html_inline }

    expect(html.content).to eq("<span>")
  end

  it "parses softbreaks and hardbreaks" do
    tokens = parser.parse("Line  \nNext\n")
    types = tokens.map(&:type)

    expect(types).to include(:hardbreak, :softbreak)
  end
end
