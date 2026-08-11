# frozen_string_literal: true

module Mdlint
  class Dialect
    BUILT_IN_FEATURES = {
      commonmark: [],
      gfm: %i[tables task_lists strikethrough bare_autolinks]
    }.freeze

    @features = BUILT_IN_FEATURES.dup

    class << self
      attr_reader :features

      def register(name, features: [])
        key = name.to_s.downcase.to_sym
        raise ArgumentError, "dialect name cannot be empty" if key.to_s.empty?

        @features[key] = Array(features).map(&:to_sym).uniq.freeze
        key
      end

      def registered
        @features.keys
      end

      def resolve(value)
        return value if value.is_a?(self)

        new(value || :commonmark)
      end
    end

    attr_reader :name, :features

    def initialize(name = :commonmark, features: nil)
      @name = name.to_s.downcase.to_sym
      @features = Array(features || self.class.features.fetch(@name, [])).map(&:to_sym).freeze
    end

    def gfm?
      feature?(:tables) && feature?(:strikethrough)
    end

    def feature?(feature)
      @features.include?(feature.to_sym)
    end

    def to_sym
      @name
    end
  end
end
