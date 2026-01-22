# frozen_string_literal: true

module Mdlint
  module Linter
    module Rules
      class HeadingStyle < Rule
        self.rule_id = "MD003"
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

        def fix(tokens, _source)
          tokens
        end
      end
    end
  end
end
