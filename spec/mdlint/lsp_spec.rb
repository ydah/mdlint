# frozen_string_literal: true

require "json"
require "stringio"

RSpec.describe Mdlint::Lsp::Server do
  def frame(message)
    payload = JSON.generate(message)
    "Content-Length: #{payload.bytesize}\r\n\r\n#{payload}"
  end

  def messages(output)
    data = output.string
    result = []
    until data.empty?
      header, data = data.split("\r\n\r\n", 2)
      length = header[/Content-Length: (\d+)/i, 1].to_i
      payload = data.slice!(0, length)
      result << JSON.parse(payload)
    end
    result
  end

  it "supports diagnostics, formatting, and code actions over JSON-RPC" do
    uri = "file:///tmp/example.md"
    input = StringIO.new(
      frame("jsonrpc" => "2.0", "id" => 1, "method" => "initialize", "params" => {}) +
      frame("jsonrpc" => "2.0", "method" => "textDocument/didOpen", "params" => {
        "textDocument" => { "uri" => uri, "languageId" => "markdown", "version" => 1, "text" => "# H\n\nParagraph \n" }
      }) +
      frame("jsonrpc" => "2.0", "id" => 2, "method" => "textDocument/formatting", "params" => { "textDocument" => { "uri" => uri } }) +
      frame("jsonrpc" => "2.0", "id" => 3, "method" => "textDocument/codeAction", "params" => { "textDocument" => { "uri" => uri } }) +
      frame("jsonrpc" => "2.0", "id" => 4, "method" => "shutdown", "params" => {}) +
      frame("jsonrpc" => "2.0", "method" => "exit", "params" => {})
    )
    output = StringIO.new

    described_class.new(input: input, output: output).run
    result = messages(output)

    expect(result.find { |message| message["id"] == 1 }["result"]["capabilities"]).to include("documentFormattingProvider" => true)
    diagnostics = result.find { |message| message["method"] == "textDocument/publishDiagnostics" }
    expect(diagnostics["params"]["diagnostics"].first["code"]).to eq("MD009")
    expect(result.find { |message| message["id"] == 2 }["result"].first["newText"]).to include("# H")
    expect(result.find { |message| message["id"] == 3 }["result"].first["title"]).to eq("Fix Markdown")
  end
end
