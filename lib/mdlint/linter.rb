# frozen_string_literal: true

require_relative "linter/violation"
require_relative "linter/rule"
require_relative "linter/rule_engine"
require_relative "linter/directive_filter"
require_relative "linter/rules/heading_style"
require_relative "linter/rules/heading_increment"
require_relative "linter/rules/no_trailing_spaces"
require_relative "linter/rules/no_multiple_blanks"
require_relative "linter/rules/first_line_heading"
require_relative "linter/rules/line_length"
require_relative "linter/rules/link_check"
require_relative "linter/rules/japanese"
require_relative "linter/rules/code_block_syntax"
require_relative "linter/rules/source_style"

module Mdlint
  module Linter
    class << self
      def check(src, options = {})
        tokens = Parser.parse(src, options)
        engine = RuleEngine.new(options)
        DirectiveFilter.apply(engine.check(tokens, src), src)
      end

      def fix(src, options = {})
        tokens = Parser.parse(src, options)
        engine = RuleEngine.new(options)
        engine.fix(tokens, src)
      end
    end
  end
end
