# frozen_string_literal: true

require_relative "state"

module Mdlint
  module Parser
    class BlockParser
      ATX_HEADING_REGEXP = /\A {0,3}(\#{1,6})(?:\s+(.*))?$/
      SETEXT_HEADING_REGEXP = /\A {0,3}(=+|-+)\s*\z/
      FENCE_OPEN_REGEXP = /\A {0,3}(`{3,}|~{3,})([^`]*)\z/
      BLOCKQUOTE_REGEXP = /\A {0,3}> ?/
      HR_REGEXP = /\A {0,3}([-*_])(?:\s*\1){2,}\s*\z/
      BULLET_LIST_REGEXP = /\A( {0,3})([-*+])\s+/
      ORDERED_LIST_REGEXP = /\A( {0,3})(\d{1,9})([.)])\s+/
      CODE_BLOCK_INDENT = /\A {4}/
      HTML_BLOCK_START_1 = /\A {0,3}<(script|pre|style|textarea)[\s>]/i
      HTML_BLOCK_START_2 = /\A {0,3}<!--/
      HTML_BLOCK_START_3 = /\A {0,3}<\?/
      HTML_BLOCK_START_4 = /\A {0,3}<![A-Z]/
      HTML_BLOCK_START_5 = /\A {0,3}<!\[CDATA\[/
      HTML_BLOCK_START_6 = /\A {0,3}<\/?(?:address|article|aside|base|basefont|blockquote|body|caption|center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h1|h2|h3|h4|h5|h6|head|header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|optgroup|option|p|param|search|section|summary|table|tbody|td|tfoot|th|thead|title|tr|track|ul)(?:\s|\/?>|$)/i
      # Reference definition: [label]: url "title"
      REFERENCE_DEF_REGEXP = /\A {0,3}\[([^\]]+)\]:\s*<?([^\s>]+)>?(?:\s+(?:"([^"]*)"|'([^']*)'|\(([^)]*)\)))?\s*$/

      def initialize(options = {})
        @options = options
      end

      def parse(src)
        state = State.new(src)

        until state.eof?
          parse_block(state)
        end

        state.tokens
      end

      private

      def parse_block(state)
        return if state.eof?

        parse_blank_line(state) ||
          parse_atx_heading(state) ||
          parse_fence(state) ||
          parse_hr(state) ||
          parse_blockquote(state) ||
          parse_bullet_list(state) ||
          parse_ordered_list(state) ||
          parse_html_block(state) ||
          parse_reference_definition(state) ||
          parse_code_block(state) ||
          parse_setext_heading(state) ||
          parse_paragraph(state)
      end

      def parse_blank_line(state)
        return false unless state.blank_line?

        state.next_line
        true
      end

      def parse_atx_heading(state)
        line = state.current_line
        match = line.match(ATX_HEADING_REGEXP)
        return false unless match

        level = match[1].length
        content = match[2]&.gsub(/\s+#+\s*\z/, "")&.strip || ""

        start_line = state.line

        state.tokens << Token.new(
          type: :heading_open,
          tag: "h#{level}",
          nesting: 1,
          level: state.level,
          markup: "#" * level,
          map: [start_line, start_line + 1]
        )

        inline_token = Token.new(
          type: :inline,
          content: content,
          level: state.level + 1,
          map: [start_line, start_line + 1]
        )
        state.tokens << inline_token

        state.tokens << Token.new(
          type: :heading_close,
          tag: "h#{level}",
          nesting: -1,
          level: state.level,
          markup: "#" * level
        )

        state.next_line
        true
      end

      def parse_setext_heading(state)
        return false if state.line.zero?

        line = state.current_line
        return false if line.match?(/\A\s*\z/)

        next_line = state.peek_line
        return false unless next_line

        match = next_line.match(SETEXT_HEADING_REGEXP)
        return false unless match

        level = match[1][0] == "=" ? 1 : 2
        content = line.strip
        start_line = state.line

        state.tokens << Token.new(
          type: :heading_open,
          tag: "h#{level}",
          nesting: 1,
          level: state.level,
          markup: match[1][0],
          map: [start_line, start_line + 2]
        )

        state.tokens << Token.new(
          type: :inline,
          content: content,
          level: state.level + 1,
          map: [start_line, start_line + 1]
        )

        state.tokens << Token.new(
          type: :heading_close,
          tag: "h#{level}",
          nesting: -1,
          level: state.level,
          markup: match[1][0]
        )

        state.next_line
        state.next_line
        true
      end

      def parse_fence(state)
        line = state.current_line
        match = line.match(FENCE_OPEN_REGEXP)
        return false unless match

        marker = match[1]
        info = match[2].strip
        fence_char = marker[0]
        fence_length = marker.length
        start_line = state.line
        state.next_line

        content_lines = []
        until state.eof?
          current = state.current_line
          close_match = current.match(/\A {0,3}#{fence_char}{#{fence_length},}\s*\z/)
          if close_match
            state.next_line
            break
          end
          content_lines << current
          state.next_line
        end

        state.tokens << Token.new(
          type: :fence,
          tag: "code",
          content: content_lines.join("\n") + (content_lines.any? ? "\n" : ""),
          markup: marker,
          info: info,
          map: [start_line, state.line]
        )

        true
      end

      def parse_hr(state)
        line = state.current_line
        return false unless line.match?(HR_REGEXP)

        state.tokens << Token.new(
          type: :hr,
          tag: "hr",
          markup: line.strip[0],
          map: [state.line, state.line + 1]
        )

        state.next_line
        true
      end

      def parse_blockquote(state)
        line = state.current_line
        return false unless line.match?(BLOCKQUOTE_REGEXP)

        start_line = state.line
        content_lines = []

        while !state.eof? && state.current_line.match?(BLOCKQUOTE_REGEXP)
          content_lines << state.current_line.sub(BLOCKQUOTE_REGEXP, "")
          state.next_line
        end

        state.tokens << Token.new(
          type: :blockquote_open,
          tag: "blockquote",
          nesting: 1,
          level: state.level,
          markup: ">",
          map: [start_line, state.line]
        )

        state.level += 1
        inner_content = content_lines.join("\n")
        inner_parser = BlockParser.new(@options)
        inner_tokens = inner_parser.parse(inner_content)

        inner_tokens.each do |token|
          token.level += state.level
          if token.map
            token.map = token.map.map { |l| l + start_line }
          end
          state.tokens << token
        end

        state.level -= 1

        state.tokens << Token.new(
          type: :blockquote_close,
          tag: "blockquote",
          nesting: -1,
          level: state.level,
          markup: ">"
        )

        true
      end

      def parse_bullet_list(state)
        line = state.current_line
        match = line.match(BULLET_LIST_REGEXP)
        return false unless match

        marker = match[2]
        start_line = state.line

        state.tokens << Token.new(
          type: :bullet_list_open,
          tag: "ul",
          nesting: 1,
          level: state.level,
          markup: marker,
          map: [start_line, nil]
        )
        list_token_index = state.tokens.length - 1

        state.level += 1
        parse_list_items(state, BULLET_LIST_REGEXP, marker)
        state.level -= 1

        state.tokens[list_token_index].map[1] = state.line

        state.tokens << Token.new(
          type: :bullet_list_close,
          tag: "ul",
          nesting: -1,
          level: state.level,
          markup: marker
        )

        true
      end

      def parse_ordered_list(state)
        line = state.current_line
        match = line.match(ORDERED_LIST_REGEXP)
        return false unless match

        start_num = match[2].to_i
        delimiter = match[3]
        start_line = state.line

        state.tokens << Token.new(
          type: :ordered_list_open,
          tag: "ol",
          nesting: 1,
          level: state.level,
          markup: delimiter,
          attrs: { start: start_num },
          map: [start_line, nil]
        )
        list_token_index = state.tokens.length - 1

        state.level += 1
        parse_ordered_list_items(state, delimiter)
        state.level -= 1

        state.tokens[list_token_index].map[1] = state.line

        state.tokens << Token.new(
          type: :ordered_list_close,
          tag: "ol",
          nesting: -1,
          level: state.level,
          markup: delimiter
        )

        true
      end

      def parse_list_items(state, pattern, _marker)
        while !state.eof?
          line = state.current_line
          match = line.match(pattern)
          break unless match

          item_start = state.line
          content = line.sub(pattern, "")

          state.tokens << Token.new(
            type: :list_item_open,
            tag: "li",
            nesting: 1,
            level: state.level,
            map: [item_start, nil]
          )
          item_token_index = state.tokens.length - 1

          state.level += 1
          state.next_line

          item_content_lines = [content]
          while !state.eof? && !state.blank_line? && !state.current_line.match?(pattern)
            if state.current_line.match?(/\A\s+/)
              item_content_lines << state.current_line.sub(/\A\s+/, "")
              state.next_line
            else
              break
            end
          end

          paragraph_content = item_content_lines.join("\n").strip
          unless paragraph_content.empty?
            state.tokens << Token.new(
              type: :paragraph_open,
              tag: "p",
              nesting: 1,
              level: state.level,
              map: [item_start, state.line]
            )

            state.tokens << Token.new(
              type: :inline,
              content: paragraph_content,
              level: state.level + 1,
              map: [item_start, state.line]
            )

            state.tokens << Token.new(
              type: :paragraph_close,
              tag: "p",
              nesting: -1,
              level: state.level
            )
          end

          state.level -= 1
          state.tokens[item_token_index].map[1] = state.line

          state.tokens << Token.new(
            type: :list_item_close,
            tag: "li",
            nesting: -1,
            level: state.level
          )

          state.skip_blank_lines
        end
      end

      def parse_ordered_list_items(state, delimiter)
        pattern = /\A( {0,3})(\d{1,9})([#{Regexp.escape(delimiter)}])\s+/

        while !state.eof?
          line = state.current_line
          match = line.match(pattern)
          break unless match

          item_start = state.line
          content = line.sub(pattern, "")

          state.tokens << Token.new(
            type: :list_item_open,
            tag: "li",
            nesting: 1,
            level: state.level,
            map: [item_start, nil]
          )
          item_token_index = state.tokens.length - 1

          state.level += 1
          state.next_line

          item_content_lines = [content]
          while !state.eof? && !state.blank_line? && !state.current_line.match?(pattern)
            if state.current_line.match?(/\A\s+/)
              item_content_lines << state.current_line.sub(/\A\s+/, "")
              state.next_line
            else
              break
            end
          end

          paragraph_content = item_content_lines.join("\n").strip
          unless paragraph_content.empty?
            state.tokens << Token.new(
              type: :paragraph_open,
              tag: "p",
              nesting: 1,
              level: state.level,
              map: [item_start, state.line]
            )

            state.tokens << Token.new(
              type: :inline,
              content: paragraph_content,
              level: state.level + 1,
              map: [item_start, state.line]
            )

            state.tokens << Token.new(
              type: :paragraph_close,
              tag: "p",
              nesting: -1,
              level: state.level
            )
          end

          state.level -= 1
          state.tokens[item_token_index].map[1] = state.line

          state.tokens << Token.new(
            type: :list_item_close,
            tag: "li",
            nesting: -1,
            level: state.level
          )

          state.skip_blank_lines
        end
      end

      def parse_html_block(state)
        line = state.current_line

        return false unless line.match?(HTML_BLOCK_START_1) ||
                            line.match?(HTML_BLOCK_START_2) ||
                            line.match?(HTML_BLOCK_START_3) ||
                            line.match?(HTML_BLOCK_START_4) ||
                            line.match?(HTML_BLOCK_START_5) ||
                            line.match?(HTML_BLOCK_START_6)

        start_line = state.line
        content_lines = []

        until state.eof?
          content_lines << state.current_line
          state.next_line
          break if state.blank_line?
        end

        state.tokens << Token.new(
          type: :html_block,
          content: content_lines.join("\n") + "\n",
          map: [start_line, state.line]
        )

        true
      end

      def parse_code_block(state)
        return false unless state.current_line.match?(CODE_BLOCK_INDENT)

        start_line = state.line
        content_lines = []

        while !state.eof? && state.current_line.match?(CODE_BLOCK_INDENT)
          content_lines << state.current_line.sub(CODE_BLOCK_INDENT, "")
          state.next_line
        end

        state.tokens << Token.new(
          type: :code_block,
          tag: "code",
          content: content_lines.join("\n") + "\n",
          map: [start_line, state.line]
        )

        true
      end

      def parse_reference_definition(state)
        line = state.current_line
        match = line.match(REFERENCE_DEF_REGEXP)
        return false unless match

        label = match[1].downcase
        url = match[2]
        title = match[3] || match[4] || match[5]

        state.tokens << Token.new(
          type: :reference_definition,
          attrs: {
            label: label,
            url: url,
            title: title
          }.compact,
          map: [state.line, state.line + 1]
        )

        state.next_line
        true
      end

      def parse_paragraph(state)
        return false if state.blank_line?

        start_line = state.line
        content_lines = []

        while !state.eof? && !state.blank_line?
          line = state.current_line
          break if line.match?(ATX_HEADING_REGEXP) ||
                   line.match?(FENCE_OPEN_REGEXP) ||
                   line.match?(HR_REGEXP) ||
                   line.match?(BLOCKQUOTE_REGEXP) ||
                   line.match?(BULLET_LIST_REGEXP) ||
                   line.match?(ORDERED_LIST_REGEXP) ||
                   line.match?(REFERENCE_DEF_REGEXP)

          if state.peek_line&.match?(SETEXT_HEADING_REGEXP)
            break if content_lines.any?
          end

          content_lines << line
          state.next_line
        end

        return false if content_lines.empty?

        state.tokens << Token.new(
          type: :paragraph_open,
          tag: "p",
          nesting: 1,
          level: state.level,
          map: [start_line, state.line]
        )

        state.tokens << Token.new(
          type: :inline,
          content: content_lines.join("\n"),
          level: state.level + 1,
          map: [start_line, state.line]
        )

        state.tokens << Token.new(
          type: :paragraph_close,
          tag: "p",
          nesting: -1,
          level: state.level
        )

        true
      end
    end
  end
end
