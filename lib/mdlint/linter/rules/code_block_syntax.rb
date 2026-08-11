# frozen_string_literal: true

require "json"
require "ripper"

module Mdlint
  module Linter
    module Rules
      class CodeBlockSyntax < Rule
        self.rule_id = "MD040"
        self.aliases = ["code-block-syntax"]
        self.description = "Supported fenced code blocks should have valid syntax"

        SUPPORTED_LANGUAGES = %w[json ruby].freeze

        def check(tokens, _source)
          return @violations unless @options[:check_code_blocks]

          tokens.each do |token|
            next unless token.type == :fence

            language = token.info.to_s.split.first.to_s.downcase
            if language.empty?
              add_violation(message: "Code block should specify a language", line: line_for(token), fixable: false)
              next
            end
            next unless SUPPORTED_LANGUAGES.include?(language)

            error = syntax_error(language, token.content)
            next unless error

            add_violation(
              message: "Invalid #{language} syntax: #{error}",
              line: line_for(token),
              fixable: false
            )
          end
          @violations
        end

        private

        def line_for(token)
          (token.map&.first || 0) + 1
        end

        def syntax_error(language, content)
          case language
          when "json"
            JSON.parse(content)
            nil
          when "ruby"
            Ripper.sexp(content) ? nil : "parser rejected the source"
          end
        rescue JSON::ParserError => error
          error.message.lines.first.to_s.strip
        end
      end
    end
  end
end
