# frozen_string_literal: true

require_relative "linter/violation"
require_relative "linter/rule"
require_relative "linter/rule_engine"
require_relative "linter/rules/heading_style"
require_relative "linter/rules/heading_increment"
require_relative "linter/rules/no_trailing_spaces"
require_relative "linter/rules/no_multiple_blanks"
require_relative "linter/rules/first_line_heading"

module Mdlint
  module Linter
    class << self
      def check(src, options = {})
        tokens = Parser.parse(src)
        engine = RuleEngine.new(options)
        engine.check(tokens, src)
      end

      def fix(src, options = {})
        tokens = Parser.parse(src)
        engine = RuleEngine.new(options)
        engine.fix(tokens, src)
      end
    end
  end
end
