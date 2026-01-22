# frozen_string_literal: true

module Mdlint
  module Linter
    module Rules
      class NoTrailingSpaces < Rule
        self.rule_id = "MD009"
        self.description = "Trailing spaces"

        def check(_tokens, source)
          source.each_line.with_index(1) do |line, line_num|
            trimmed = line.chomp
            next unless trimmed.end_with?(" ") || trimmed.end_with?("\t")
            next if trimmed.end_with?("  ") && line_num < source.lines.count

            add_violation(
              message: "Trailing spaces",
              line: line_num,
              column: trimmed.rstrip.length + 1,
              fixable: true
            )
          end
          @violations
        end

        def fix(_tokens, source)
          source.each_line.map do |line|
            if line.end_with?("  \n")
              line
            else
              line.rstrip + "\n"
            end
          end.join
        end
      end
    end
  end
end
