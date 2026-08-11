# frozen_string_literal: true

module Mdlint
  class Dialect
    attr_reader :name

    def initialize(name = :commonmark)
      @name = name.to_s.downcase.to_sym
    end

    def gfm?
      @name == :gfm
    end

    def self.resolve(value)
      return value if value.is_a?(self)

      new(value || :commonmark)
    end
  end
end
