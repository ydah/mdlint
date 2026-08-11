# frozen_string_literal: true

require_relative "../../dialect"

module Mdlint
  module Linter
    module Rules
      module SourceStyleSupport
        FENCE_REGEXP = /\A {0,3}(`{3,}|~{3,})/
        LIST_MARKER_REGEXP = /\A( {0,3}(?:[-+*]|\d+[.)]))([ \t]+)(\S.*)?\z/

        private

        def lines(source)
          source.lines
        end

        def fenced_lines(source)
          in_fence = false
          source.each_line.with_index(1).filter_map do |line, line_number|
            marker = line.chomp.match(FENCE_REGEXP)
            in_fence = !in_fence if marker
            [line_number, in_fence, marker]
          end
        end

        def outside_fence?(fence_state)
          !fence_state
        end

        def line_is_blank?(line)
          line.to_s.match?(/\A\s*\z/)
        end

        def inline_tokens(tokens)
          tokens.select { |token| token.type == :inline }.flat_map(&:children)
        end
      end

      class NoHardTabs < Rule
        include SourceStyleSupport

        self.rule_id = "MD010"
        self.aliases = ["no-hard-tabs"]
        self.description = "Hard tabs should not be used"

        def check(_tokens, source)
          in_fence = false
          source.each_line.with_index(1) do |line, line_number|
            in_fence = !in_fence if line.match?(FENCE_REGEXP)
            next if in_fence && @options.fetch(:ignore_code_blocks, false)
            next unless line.include?("\t")

            add_violation(message: "Hard tab character", line: line_number, column: line.index("\t").to_i + 1, fixable: true)
          end
          @violations
        end

        def fix(_tokens, source)
          source.each_line.map { |line| line.gsub("\t", "  ") }.join
        end
      end

      class NoSpaceAfterHash < Rule
        self.rule_id = "MD018"
        self.aliases = ["no-missing-space-atx"]
        self.description = "No space after the hash on an ATX heading"

        def check(_tokens, source)
          source.each_line.with_index(1) do |line, line_number|
            next unless line.chomp.match?(/\A {0,3}\#{1,6}(?!\#)\S/)

            add_violation(message: "Add a space after the heading marker", line: line_number, fixable: true)
          end
          @violations
        end

        def fix(_tokens, source)
          source.each_line.map { |line| line.sub(/\A( {0,3}\#{1,6})(?!\#)(\S)/, '\\1 \\2') }.join
        end
      end

      class NoMultipleSpacesAfterHash < Rule
        self.rule_id = "MD019"
        self.aliases = ["no-multiple-space-atx"]
        self.description = "No more than one space after the hash on an ATX heading"

        def check(_tokens, source)
          source.each_line.with_index(1) do |line, line_number|
            next unless line.chomp.match?(/\A {0,3}#+ {2,}\S/)

            add_violation(message: "Use one space after the heading marker", line: line_number, fixable: true)
          end
          @violations
        end

        def fix(_tokens, source)
          source.each_line.map { |line| line.sub(/\A( {0,3}#+) {2,}/, '\\1 ') }.join
        end
      end

      class NoMultipleSpacesAfterBlockquote < Rule
        self.rule_id = "MD027"
        self.aliases = ["no-multiple-space-blockquote"]
        self.description = "No more than one space after a blockquote marker"

        def check(_tokens, source)
          source.each_line.with_index(1) do |line, line_number|
            next unless line.chomp.match?(/\A {0,3}> {2,}/)

            add_violation(message: "Use one space after the blockquote marker", line: line_number, fixable: true)
          end
          @violations
        end

        def fix(_tokens, source)
          source.each_line.map { |line| line.sub(/\A( {0,3}>) {2,}/, '\\1 ') }.join
        end
      end

      class ListMarkerSpace < Rule
        self.rule_id = "MD030"
        self.aliases = ["list-marker-space"]
        self.description = "List markers should be followed by one space"

        def check(_tokens, source)
          source.each_line.with_index(1) do |line, line_number|
            match = line.chomp.match(/\A( {0,3}(?:[-+*]|\d+[.)]))([ \t]+)(\S)/)
            next unless match && match[2] != " "

            add_violation(message: "Use one space after a list marker", line: line_number, fixable: true)
          end
          @violations
        end

        def fix(_tokens, source)
          source.each_line.map { |line| line.sub(/\A( {0,3}(?:[-+*]|\d+[.)]))[ \t]+/, '\\1 ') }.join
        end
      end

      class FencedCodeBlankLines < Rule
        include SourceStyleSupport

        self.rule_id = "MD031"
        self.aliases = ["blanks-around-fences"]
        self.description = "Fenced code blocks should be surrounded by blank lines"

        def check(_tokens, source)
          source_lines = lines(source)
          in_fence = false
          source_lines.each_with_index do |line, index|
            next unless line.chomp.match?(FENCE_REGEXP)

            if !in_fence && index.positive? && !line_is_blank?(source_lines[index - 1])
              add_violation(message: "Add a blank line before the fenced code block", line: index + 1)
            elsif in_fence && index < source_lines.length - 1 && !line_is_blank?(source_lines[index + 1])
              add_violation(message: "Add a blank line after the fenced code block", line: index + 1)
            end
            in_fence = !in_fence
          end
          @violations
        end
      end

      class ListBlankLines < Rule
        include SourceStyleSupport

        self.rule_id = "MD032"
        self.aliases = ["blanks-around-lists"]
        self.description = "Lists should be surrounded by blank lines"

        def check(_tokens, source)
          source_lines = lines(source)
          list_indexes = source_lines.each_index.select { |index| source_lines[index].match?(LIST_MARKER_REGEXP) }
          return @violations if list_indexes.empty?

          first = list_indexes.first
          last = list_indexes.last
          if first.positive? && !line_is_blank?(source_lines[first - 1])
            add_violation(message: "Add a blank line before the list", line: first + 1)
          end
          if last < source_lines.length - 1 && !line_is_blank?(source_lines[last + 1])
            add_violation(message: "Add a blank line after the list", line: last + 1)
          end
          @violations
        end
      end

      class NoBareUrls < Rule
        include SourceStyleSupport

        self.rule_id = "MD034"
        self.aliases = ["no-bare-urls"]
        self.description = "Bare URLs should be enclosed in angle brackets"

        def check(tokens, source)
          return @violations unless Dialect.resolve(@options[:dialect]).feature?(:bare_autolinks)

          source.each_line.with_index(1) do |line, line_number|
            next if line.match?(FENCE_REGEXP)
            next unless line.match?(%r{(?<![<\w"'=(])https?://[^\s<>]+})

            add_violation(message: "Enclose bare URLs in angle brackets", line: line_number, fixable: false)
          end
          @violations
        end
      end

      class NoSpaceInEmphasis < Rule
        include SourceStyleSupport

        self.rule_id = "MD037"
        self.aliases = ["no-space-in-emphasis"]
        self.description = "Emphasis markers should not contain extra spaces"

        def check(_tokens, source)
          source.each_line.with_index(1) do |line, line_number|
            next unless line.match?(/(?:\*\*|__|(?<!\*)\*)(?:\s+)[^\n]+?(?:\s+)(?:\*\*|__|(?<!\*)\*(?!\*))/)

            add_violation(message: "Remove spaces inside emphasis markers", line: line_number, fixable: false)
          end
          @violations
        end
      end

      class NoSpaceInCode < Rule
        include SourceStyleSupport

        self.rule_id = "MD038"
        self.aliases = ["no-space-in-code"]
        self.description = "Code spans should not contain extra spaces"

        def check(_tokens, source)
          source.each_line.with_index(1) do |line, line_number|
            invalid = line.scan(/(`+)([^`\n]*?)\1/).any? { |_marker, content| content.to_s != content.to_s.strip }
            next unless invalid

            add_violation(message: "Remove spaces inside code span markers", line: line_number, fixable: false)
          end
          @violations
        end
      end

      class FencedCodeStyle < Rule
        include SourceStyleSupport

        self.rule_id = "MD046"
        self.aliases = ["fenced-code-style"]
        self.description = "Use fenced code blocks instead of indented code blocks"

        def check(_tokens, source)
          source.each_line.with_index(1) do |line, line_number|
            next unless line.match?(/\A {4}\S/)

            add_violation(message: "Use a fenced code block", line: line_number, fixable: false)
          end
          @violations
        end
      end

      class SingleTrailingNewline < Rule
        self.rule_id = "MD047"
        self.aliases = ["single-trailing-newline"]
        self.description = "Files should end with a single newline"

        def check(_tokens, source)
          return @violations if source.empty? || source.end_with?("\n") && !source.end_with?("\n\n")

          add_violation(message: "File should end with a single newline", line: source.lines.length, fixable: true)
          @violations
        end

        def fix(_tokens, source)
          source.rstrip + "\n"
        end
      end

      class EmphasisStyle < Rule
        include SourceStyleSupport

        self.rule_id = "MD049"
        self.aliases = ["emphasis-style"]
        self.description = "Emphasis style should be consistent"

        def check(tokens, _source)
          expected = @options.fetch(:emphasis_style, :asterisk).to_s
          inline_tokens(tokens).each do |token|
            next unless token.type == :em_open
            next unless (expected == "asterisk" && token.markup == "_") || (expected == "underscore" && token.markup == "*")

            add_violation(message: "Use #{expected} emphasis markers", line: 1, fixable: false)
          end
          @violations
        end
      end

      class StrongStyle < Rule
        include SourceStyleSupport

        self.rule_id = "MD050"
        self.aliases = ["strong-style"]
        self.description = "Strong style should be consistent"

        def check(tokens, _source)
          expected = @options.fetch(:strong_style, :asterisk).to_s
          inline_tokens(tokens).each do |token|
            next unless token.type == :strong_open
            next unless (expected == "asterisk" && token.markup == "__") || (expected == "underscore" && token.markup == "**")

            add_violation(message: "Use #{expected} strong markers", line: 1, fixable: false)
          end
          @violations
        end
      end
    end
  end
end
