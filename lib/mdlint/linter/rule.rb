# frozen_string_literal: true

module Mdlint
  module Linter
    class Rule
      class << self
        attr_accessor :rule_id, :description

        def inherited(subclass)
          super
          RuleRegistry.register(subclass)
        end
      end

      attr_reader :violations

      def initialize
        @violations = []
      end

      def check(_tokens, _source)
        raise NotImplementedError, "Subclasses must implement #check"
      end

      def fix(_tokens, _source)
        raise NotImplementedError, "Subclasses must implement #fix"
      end

      protected

      def add_violation(message:, line:, column: nil, fixable: false)
        @violations << Violation.new(
          rule_id: self.class.rule_id,
          message: message,
          line: line,
          column: column,
          fixable: fixable
        )
      end
    end

    class RuleRegistry
      @rules = []

      class << self
        attr_reader :rules

        def register(rule_class)
          @rules << rule_class
        end

        def all
          @rules
        end

        def find(rule_id)
          @rules.find { |r| r.rule_id == rule_id }
        end

        def clear
          @rules = []
        end
      end
    end
  end
end
