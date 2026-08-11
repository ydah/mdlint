# frozen_string_literal: true

module Mdlint
  module Parser
    class State
      attr_reader :src, :lines, :raw_lines, :line_offsets
      attr_accessor :line, :pos, :tokens, :level

      def initialize(src)
        @src = src
        @raw_lines = src.split("\n", -1)
        @lines = @raw_lines.map { |line| expand_tabs(line) }
        @line_offsets = build_line_offsets
        @line = 0
        @pos = 0
        @tokens = []
        @level = 0
      end

      def eof?
        @line >= @lines.length
      end

      def current_line
        @lines[@line]
      end

      def raw_line
        @raw_lines[@line]
      end

      def next_line
        @line += 1
      end

      def skip_blank_lines
        while !eof? && blank_line?(@line)
          @line += 1
        end
      end

      def blank_line?(line_num = @line)
        return true if line_num >= @lines.length

        @lines[line_num].match?(/\A\s*\z/)
      end

      def remaining_lines
        @lines[@line..]
      end

      def peek_line(offset = 1)
        @lines[@line + offset]
      end

      private

      def expand_tabs(line)
        column = 0
        line.each_char.with_object(+'') do |character, expanded|
          if character == "\t"
            spaces = 4 - (column % 4)
            expanded << (" " * spaces)
            column += spaces
          else
            expanded << character
            column += 1
          end
        end
      end

      def build_line_offsets
        offsets = [0]
        @lines.each do |line|
          offsets << offsets.last + line.length + 1
        end
        offsets
      end
    end
  end
end
