# frozen_string_literal: true

module Mdlint
  module Linter
    module Rules
      class HeadingIncrement < Rule
        self.rule_id = "MD001"
        self.aliases = ["heading-increment"]
        self.description = "Heading levels should only increment by one level at a time"

        def check(tokens, _source)
          last_level = 0

          tokens.each do |token|
            next unless token.type == :heading_open

            level = token.tag.to_s[1].to_i
            if last_level > 0 && level > last_level + 1
              add_violation(
                message: "Heading level jumped from h#{last_level} to h#{level}",
                line: (token.map&.first || 0) + 1,
                fixable: false
              )
            end
            last_level = level
          end

          @violations
        end

        def fix(_tokens, source)
          source
        end
      end
    end
  end
end
