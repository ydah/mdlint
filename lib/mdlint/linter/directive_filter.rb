# frozen_string_literal: true

require "set"

module Mdlint
  module Linter
    class DirectiveFilter
      DIRECTIVE_REGEXP = /<!--\s*mdlint-(disable-next-line|disable-file|disable|enable)(?:\s+([^>]*?))?\s*-->/i
      FENCE_REGEXP = /\A {0,3}(`{3,}|~{3,})/

      class << self
        def apply(violations, source)
          new(source).filter(violations)
        end
      end

      def initialize(source)
        @disabled_by_line = {}
        @file_disabled = false
        scan(source)
      end

      def filter(violations)
        return [] if @file_disabled

        violations.reject do |violation|
          disabled = @disabled_by_line.fetch(violation.line, Set.new)
          disabled.include?("*") || disabled.include?(RuleRegistry.normalize_id(violation.rule_id))
        end
      end

      private

      def scan(source)
        disabled = Set.new
        next_line = {}
        fence = nil

        source.each_line.with_index(1) do |line, line_number|
          current_fence = line.match(FENCE_REGEXP)
          if current_fence
            marker = current_fence[1]
            if fence && marker[0] == fence[0] && marker.length >= fence.length
              fence = nil
            elsif fence.nil?
              fence = marker
            end
            @disabled_by_line[line_number] = disabled.dup
            next
          end

          if fence
            @disabled_by_line[line_number] = disabled.dup
            next
          end

          directive = line.match(DIRECTIVE_REGEXP)
          apply_directive(directive, disabled, next_line, line_number) if directive
          line_disabled = disabled.dup
          line_disabled.merge(next_line.delete(line_number) || Set.new)
          @disabled_by_line[line_number] = line_disabled
        end
      end

      def apply_directive(directive, disabled, next_line, line_number)
        action = directive[1].downcase
        ids = normalize_ids(directive[2])

        case action
        when "disable-file"
          @file_disabled = true
        when "disable-next-line"
          next_line[line_number + 1] ||= Set.new
          next_line[line_number + 1].merge(ids)
        when "disable"
          disabled.merge(ids)
        when "enable"
          ids.include?("*") ? disabled.clear : ids.each { |id| disabled.delete(id) }
        end
      end

      def normalize_ids(value)
        ids = value.to_s.split(/[\s,]+/).reject(&:empty?)
        return Set["*"] if ids.empty?

        Set.new(ids.map { |id| RuleRegistry.normalize_id(id) })
      end
    end
  end
end
