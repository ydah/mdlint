# frozen_string_literal: true

require "json"
require "uri"

module Mdlint
  module Lsp
    class Server
      SEVERITY = { error: 1, warning: 2, info: 3 }.freeze

      def initialize(input: $stdin, output: $stdout)
        @input = input
        @output = output
        @documents = {}
        @running = true
      end

      def run
        while @running
          message = read_message
          break unless message

          response = handle_message(message)
          write_message(response) if response
        end
        0
      end

      private

      def read_message
        headers = {}
        loop do
          line = @input.gets
          return nil unless line
          break if line == "\r\n" || line == "\n"

          key, value = line.split(":", 2)
          headers[key.downcase] = value.to_s.strip if key && value
        end
        length = headers.fetch("content-length").to_i
        payload = @input.read(length)
        return nil unless payload && payload.bytesize == length

        JSON.parse(payload)
      rescue JSON::ParserError, KeyError
        nil
      end

      def write_message(message)
        payload = JSON.generate(message)
        @output.write("Content-Length: #{payload.bytesize}\r\n\r\n")
        @output.write(payload)
        @output.flush if @output.respond_to?(:flush)
      end

      def handle_message(message)
        method = message["method"]
        params = message["params"] || {}
        id = message["id"]

        case method
        when "initialize"
          response(id, {
            capabilities: {
              textDocumentSync: 1,
              documentFormattingProvider: true,
              codeActionProvider: true
            },
            serverInfo: { name: "mdlint", version: Mdlint::VERSION }
          })
        when "initialized"
          nil
        when "shutdown"
          response(id, nil)
        when "exit"
          @running = false
          nil
        when "textDocument/didOpen"
          update_document(params.dig("textDocument", "uri"), params.dig("textDocument", "text"))
          publish_diagnostics(params.dig("textDocument", "uri"))
          nil
        when "textDocument/didChange"
          uri = params.dig("textDocument", "uri")
          change = Array(params["contentChanges"]).last
          text = change.is_a?(Hash) ? change["text"] : nil
          update_document(uri, text)
          publish_diagnostics(uri)
          nil
        when "textDocument/didClose"
          @documents.delete(params.dig("textDocument", "uri"))
          nil
        when "textDocument/formatting"
          response(id, formatting_edits(params.dig("textDocument", "uri")))
        when "textDocument/codeAction"
          response(id, code_actions(params.dig("textDocument", "uri")))
        else
          response(id, nil) if id
        end
      end

      def response(id, result)
        { jsonrpc: "2.0", id: id, result: result }
      end

      def notification(method, params)
        { jsonrpc: "2.0", method: method, params: params }
      end

      def update_document(uri, text)
        return unless uri && text

        @documents[uri] = text
      end

      def formatting_edits(uri)
        text = @documents[uri]
        return [] unless text

        [{ range: full_range(text), newText: Mdlint.format(text) }]
      end

      def code_actions(uri)
        text = @documents[uri]
        return [] unless text

        fixed = Mdlint.fix(text)
        return [] if fixed == text

        [{
          title: "Fix Markdown",
          kind: "quickfix",
          isPreferred: true,
          edit: { changes: { uri => [{ range: full_range(text), newText: fixed }] } }
        }]
      end

      def publish_diagnostics(uri)
        text = @documents[uri]
        return unless text

        diagnostics = Mdlint.lint(text, filename: uri_path(uri)).map do |violation|
          start_character = [violation.column.to_i - 1, 0].max
          {
            range: {
              start: { line: violation.line - 1, character: start_character },
              end: { line: violation.line - 1, character: start_character + 1 }
            },
            severity: SEVERITY.fetch(violation.severity, 2),
            code: violation.rule_id,
            source: "mdlint",
            message: violation.message
          }
        end
        write_message(notification("textDocument/publishDiagnostics", { uri: uri, diagnostics: diagnostics }))
      end

      def full_range(text)
        lines = text.lines
        last_line = [lines.length - 1, 0].max
        last_character = lines.last ? lines.last.chomp.length : 0
        { start: { line: 0, character: 0 }, end: { line: last_line, character: last_character } }
      end

      def uri_path(uri)
        return nil unless uri
        return uri unless uri.start_with?("file:")

        path = URI.parse(uri).path
        URI.decode_www_form_component(path.to_s)
      rescue URI::InvalidURIError
        uri
      end
    end
  end
end
