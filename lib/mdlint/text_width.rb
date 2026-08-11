# frozen_string_literal: true

module Mdlint
  module TextWidth
    class << self
      def measure(text)
        text.to_s.each_codepoint.sum { |codepoint| wide?(codepoint) ? 2 : 1 }
      end

      def take(text, maximum)
        width = 0
        result = +""
        text.each_char do |character|
          character_width = measure(character)
          break if width + character_width > maximum

          result << character
          width += character_width
        end
        result
      end

      private

      def wide?(codepoint)
        (0x1100..0x115F).cover?(codepoint) ||
          (0x2329..0x232A).cover?(codepoint) ||
          (0x2E80..0xA4CF).cover?(codepoint) ||
          (0xAC00..0xD7A3).cover?(codepoint) ||
          (0xF900..0xFAFF).cover?(codepoint) ||
          (0xFE10..0xFE19).cover?(codepoint) ||
          (0xFE30..0xFE6F).cover?(codepoint) ||
          (0xFF00..0xFF60).cover?(codepoint) ||
          (0xFFE0..0xFFE6).cover?(codepoint) ||
          (0x1F300..0x1FAFF).cover?(codepoint)
      end
    end
  end
end
