# frozen_string_literal: true

module Mdlint
  module Linter
    class Violation
      attr_reader :rule_id, :message, :line, :column, :severity, :fixable

      def initialize(rule_id:, message:, line:, column: nil, severity: :warning, fixable: false)
        @rule_id = rule_id
        @message = message
        @line = line
        @column = column
        @severity = severity
        @fixable = fixable
      end

      def to_s
        location = column ? "#{line}:#{column}" : line.to_s
        "[#{rule_id}] #{location}: #{message}"
      end

      def fixable?
        @fixable
      end

      def error?
        @severity == :error
      end

      def warning?
        @severity == :warning
      end
    end
  end
end
