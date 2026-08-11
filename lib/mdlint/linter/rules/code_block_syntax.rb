# frozen_string_literal: true

require "json"
require "open3"
require "ripper"
require "shellwords"
require "timeout"

module Mdlint
  module Linter
    module Rules
      class CodeBlockSyntax < Rule
        self.rule_id = "MD040"
        self.aliases = ["code-block-syntax"]
        self.description = "Supported fenced code blocks should have valid syntax"

        SUPPORTED_LANGUAGES = %w[json ruby].freeze

        def check(tokens, _source)
          commands = @options.fetch(:code_block_commands, {})
          return @violations unless @options[:check_code_blocks] || !commands.empty?

          tokens.each do |token|
            next unless token.type == :fence

            language = token.info.to_s.split.first.to_s.downcase
            if language.empty?
              add_violation(message: "Code block should specify a language", line: line_for(token), fixable: false)
              next
            end
            unless SUPPORTED_LANGUAGES.include?(language) || commands.key?(language)
              next
            end

            error = if SUPPORTED_LANGUAGES.include?(language)
                      syntax_error(language, token.content)
                    else
                      command_error(commands.fetch(language), token.content)
                    end
            next unless error

            add_violation(
              message: "Invalid #{language} syntax: #{error}",
              line: line_for(token),
              fixable: false
            )
          end
          @violations
        end

        def fix(tokens, source)
          commands = @options.fetch(:code_block_format_commands, {})
          return source if commands.empty?

          lines = source.lines
          tokens.reverse_each do |token|
            next unless token.type == :fence

            language = token.info.to_s.split.first.to_s.downcase
            command = commands[language]
            next unless command

            formatted = command_output(command, token.content)
            next unless formatted

            start_line = token.map&.first
            end_line = token.map&.last
            next unless start_line && end_line

            closing_line = end_line - 1
            closing_line = end_line unless lines[closing_line].to_s.match?(/\A {0,3}(`{3,}|~{3,})\s*\r?\n?\z/)
            replacement = formatted.end_with?("\n") ? formatted : "#{formatted}\n"
            body_length = [closing_line - start_line - 1, 0].max
            lines.slice!(start_line + 1, body_length)
            lines.insert(start_line + 1, *replacement.lines)
          end
          lines.join
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

        def command_error(command, content)
          result = command_result(command, content)
          return nil if result[:status].success?

          result[:stderr].lines.first.to_s.strip.empty? ? "command exited with #{result[:status].exitstatus}" : result[:stderr].lines.first.strip
        rescue StandardError => error
          "#{error.class}: #{error.message}"
        end

        def command_output(command, content)
          result = command_result(command, content)
          return result[:stdout] if result[:status].success?

          nil
        rescue StandardError
          nil
        end

        def command_result(command, content)
          argv = Shellwords.split(command)
          raise ArgumentError, "empty code block command" if argv.empty?

          stdout, stderr, status = Timeout.timeout(@options.fetch(:code_block_timeout, 10).to_i) do
            Open3.capture3(*argv, stdin_data: content)
          end
          { stdout: stdout, stderr: stderr, status: status }
        end
      end
    end
  end
end
