# frozen_string_literal: true

require_relative "parser/state"
require_relative "parser/block_parser"
require_relative "parser/inline_parser"

module Mdlint
  module Parser
    class << self
      def parse(src, options = {})
        block_parser = BlockParser.new(options)
        tokens = block_parser.parse(src)
        parse_inline_tokens(tokens, options)
        tokens
      end

      private

      def parse_inline_tokens(tokens, options)
        inline_parser = InlineParser.new(options)
        tokens.each do |token|
          next unless token.type == :inline

          token.children = inline_parser.parse(token.content)
        end
      end
    end
  end
end
