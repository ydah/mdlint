# frozen_string_literal: true

module Mdlint
  module Linter
    class Rule
      class << self
        attr_accessor :rule_id, :description, :aliases, :preset

        def inherited(subclass)
          super
          RuleRegistry.register(subclass)
        end
      end

      attr_reader :violations

      def initialize(options = {})
        @options = options
        @violations = []
      end

      def check(_tokens, _source)
        raise NotImplementedError, "Subclasses must implement #check"
      end

      def fix(_tokens, _source)
        _source
      end

      protected

      def add_violation(message:, line:, column: nil, fixable: false)
        @violations << Violation.new(
          rule_id: self.class.rule_id,
          message: message,
          line: line,
          column: column,
          fixable: fixable,
          severity: @options[:severity] || :warning
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
          normalized_id = normalize_id(rule_id)
          @rules.find { |r| r.rule_id == normalized_id }
        end

        def normalize_id(rule_id)
          value = rule_id.to_s
          value = value.upcase if value.match?(/\Amd\d+\z/i)
          rule = @rules.find do |rule_class|
            aliases = rule_class.aliases
            rule_class.rule_id == value || (aliases.is_a?(Array) && aliases.any? { |name| name.is_a?(String) && name.casecmp?(value.to_s) })
          end
          rule ? rule.rule_id : value
        end

        def clear
          @rules = []
        end
      end
    end
  end
end
