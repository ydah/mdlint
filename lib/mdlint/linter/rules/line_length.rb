# frozen_string_literal: true

require_relative "../../text_width"

module Mdlint
  module Linter
    module Rules
      class LineLength < Rule
        self.rule_id = "MD013"
        self.aliases = ["line-length"]
        self.description = "Line length should not exceed the configured limit"

        def check(_tokens, source)
          maximum = @options.fetch(:line_length, @options.fetch(:length, 80)).to_i
          return @violations if maximum <= 0

          in_fence = false
          source.each_line.with_index(1) do |line, line_number|
            stripped = line.chomp
            in_fence = !in_fence if stripped.match?(/\A {0,3}(`{3,}|~{3,})/)
            next if in_fence && @options.fetch(:ignore_code_blocks, false)
            next if TextWidth.measure(stripped) <= maximum

            add_violation(
              message: "Line length #{TextWidth.measure(stripped)} exceeds #{maximum}",
              line: line_number,
              column: maximum + 1,
              fixable: false
            )
          end

          @violations
        end
      end
    end
  end
end
