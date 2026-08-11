# frozen_string_literal: true

module Mdlint
  module Linter
    module Rules
      class HeadingStyle < Rule
        self.rule_id = "MD003"
        self.aliases = ["heading-style"]
        self.description = "Heading style should be consistent"

        def check(tokens, _source)
          tokens.each do |token|
            next unless token.type == :heading_open

            if token.markup && !token.markup.start_with?("#")
              add_violation(
                message: "Setext-style heading should be ATX-style",
                line: (token.map&.first || 0) + 1,
                fixable: true
              )
            end
          end
          @violations
        end

        def fix(tokens, source)
          lines = source.lines
          heading_tokens = tokens.select do |token|
            token.type == :heading_open && token.markup && !token.markup.start_with?("#")
          end

          heading_tokens.reverse_each do |token|
            start_line, end_line = token.map || []
            next unless start_line && end_line && end_line == start_line + 2
            next unless lines[start_line] && lines[start_line + 1]

            prefix, content = lines[start_line].match(/\A(\s*(?:>\s*)*)(.*?)(?:\r?\n)?\z/).captures
            newline = lines[start_line].end_with?("\r\n") ? "\r\n" : "\n"
            level = token.tag == "h1" ? "#" : "##"
            lines[start_line] = "#{prefix}#{level} #{content.strip}#{newline}"
            lines[start_line + 1] = nil
          end

          lines.compact.join
        end
      end
    end
  end
end
