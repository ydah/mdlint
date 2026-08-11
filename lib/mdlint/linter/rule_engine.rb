# frozen_string_literal: true

module Mdlint
  module Linter
    class RuleEngine
      attr_reader :violations

      def initialize(options = {})
        @options = options
        @configured_rules = options[:rules]
        @enabled_rules = Array(options[:rules]).map { |rule| RuleRegistry.normalize_id(rule) } if options[:rules].is_a?(Array)
        @disabled_rules = Array(options[:disable]).map { |rule| RuleRegistry.normalize_id(rule) }
        @violations = []
      end

      def check(tokens, source)
        @violations = []

        active_rules.each do |rule_class|
          rule = rule_class.new(rule_options(rule_class))
          rule.check(tokens, source)
          @violations.concat(rule.violations)
        end

        @violations.sort_by(&:line)
      end

      def fix(tokens, source)
        result = source
        current_tokens = tokens

        active_rules.each do |rule_class|
          rule = rule_class.new(rule_options(rule_class))
          result = rule.fix(current_tokens, result)
          current_tokens = Parser.parse(result, @options) if result != source
        end

        result
      end

      private

      def active_rules
        RuleRegistry.all.select do |rule_class|
          configured_enabled?(rule_class) && !@disabled_rules.include?(rule_class.rule_id)
        end
      end

      def configured_enabled?(rule_class)
        if rule_class.preset && @options[:preset].to_s != rule_class.preset.to_s
          explicitly_selected = @enabled_rules&.include?(rule_class.rule_id) || explicitly_configured?(rule_class)
          return false unless explicitly_selected
        end
        return @enabled_rules.include?(rule_class.rule_id) if @enabled_rules
        return true unless @configured_rules.is_a?(Hash)

        setting = rule_setting(rule_class)
        setting != false && (!setting.is_a?(Hash) || setting[:enabled] != false)
      end

      def explicitly_configured?(rule_class)
        return false unless @configured_rules.is_a?(Hash)

        @configured_rules.any? { |key, _value| RuleRegistry.normalize_id(key) == rule_class.rule_id }
      end

      def rule_options(rule_class)
        setting = rule_setting(rule_class)
        setting = {} unless setting.is_a?(Hash)
        global_options = @options.reject { |key, _value| %i[rules disable].include?(key) }
        setting = global_options.merge(setting.transform_keys(&:to_sym))
        setting[:severity] ||= @options[:severity] if @options[:severity]
        setting
      end

      def rule_setting(rule_class)
        return nil unless @configured_rules.is_a?(Hash)

        @configured_rules.find do |key, _value|
          RuleRegistry.normalize_id(key) == rule_class.rule_id
        end&.last
      end
    end
  end
end
