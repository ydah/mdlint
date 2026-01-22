# frozen_string_literal: true

module Mdlint
  module Linter
    class RuleEngine
      attr_reader :violations

      def initialize(options = {})
        @options = options
        @enabled_rules = options[:rules] || RuleRegistry.all.map(&:rule_id)
        @disabled_rules = options[:disable] || []
        @violations = []
      end

      def check(tokens, source)
        @violations = []

        active_rules.each do |rule_class|
          rule = rule_class.new
          rule.check(tokens, source)
          @violations.concat(rule.violations)
        end

        @violations.sort_by(&:line)
      end

      def fix(tokens, source)
        result = source

        active_rules.each do |rule_class|
          rule = rule_class.new
          result = rule.fix(tokens, result)
        end

        result
      end

      private

      def active_rules
        RuleRegistry.all.select do |rule_class|
          @enabled_rules.include?(rule_class.rule_id) &&
            !@disabled_rules.include?(rule_class.rule_id)
        end
      end
    end
  end
end
