# frozen_string_literal: true

module Mdlint
  module Linter
    module Rules
      class NoMultipleBlanks < Rule
        self.rule_id = "MD012"
        self.description = "Multiple consecutive blank lines"

        def check(_tokens, source)
          blank_count = 0

          source.each_line.with_index(1) do |line, line_num|
            if line.strip.empty?
              blank_count += 1
              if blank_count > 1
                add_violation(
                  message: "Multiple consecutive blank lines",
                  line: line_num,
                  fixable: true
                )
              end
            else
              blank_count = 0
            end
          end

          @violations
        end

        def fix(_tokens, source)
          result = []
          blank_count = 0

          source.each_line do |line|
            if line.strip.empty?
              blank_count += 1
              result << line if blank_count <= 1
            else
              blank_count = 0
              result << line
            end
          end

          result.join
        end
      end
    end
  end
end
