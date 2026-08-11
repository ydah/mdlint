# frozen_string_literal: true

module Mdlint
  module Linter
    module Rules
      class FirstLineHeading < Rule
        self.rule_id = "MD041"
        self.aliases = ["first-line-heading"]
        self.description = "First line in file should be a top-level heading"

        def check(tokens, _source)
          first_content_token = tokens.find do |t|
            %i[heading_open paragraph_open bullet_list_open ordered_list_open
               blockquote_open fence code_block hr html_block].include?(t.type) && !directive?(t)
          end

          return @violations unless first_content_token

          if first_content_token.type != :heading_open
            add_violation(
              message: "First line should be a top-level heading",
              line: (first_content_token.map&.first || 0) + 1,
              fixable: false
            )
          elsif first_content_token.tag != "h1"
            add_violation(
              message: "First heading should be h1",
              line: (first_content_token.map&.first || 0) + 1,
              fixable: false
            )
          end

          @violations
        end

        def fix(_tokens, source)
          source
        end

        private

        def directive?(token)
          token.type == :html_block && token.content.match?(/<!--\s*mdlint-(?:disable|enable)/i)
        end
      end
    end
  end
end
