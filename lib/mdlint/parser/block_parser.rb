# frozen_string_literal: true

require_relative "state"
require_relative "../dialect"

module Mdlint
  module Parser
    class BlockParser
      ATX_HEADING_REGEXP = /\A {0,3}(\#{1,6})(?:\s+(.*))?$/
      SETEXT_HEADING_REGEXP = /\A {0,3}(=+|-+)\s*\z/
      FENCE_OPEN_REGEXP = /\A {0,3}(`{3,}|~{3,})(.*)\z/
      BLOCKQUOTE_REGEXP = /\A {0,3}> ?/
      HR_REGEXP = /\A {0,3}([-*_])(?:\s*\1){2,}\s*\z/
      BULLET_LIST_REGEXP = /\A( {0,3})([-*+])\s+/
      ORDERED_LIST_REGEXP = /\A( {0,3})(\d{1,9})([.)])\s+/
      CODE_BLOCK_INDENT = /\A {4}/
      HTML_BLOCK_START_1 = /\A {0,3}<(script|pre|style|textarea)(?:[\s>]|\z)/i
      HTML_BLOCK_START_2 = /\A {0,3}<!--/
      HTML_BLOCK_START_3 = /\A {0,3}<\?/
      HTML_BLOCK_START_4 = /\A {0,3}<![A-Z]/
      HTML_BLOCK_START_5 = /\A {0,3}<!\[CDATA\[/
      HTML_BLOCK_START_6 = /\A {0,3}<\/?(?:address|article|aside|base|basefont|blockquote|body|caption|center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h1|h2|h3|h4|h5|h6|head|header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|optgroup|option|p|param|search|section|summary|table|tbody|td|tfoot|th|thead|title|tr|track|ul)(?:\s|\/?>|$)/i
      HTML_BLOCK_START_7 = /\A {0,3}<\/?[A-Za-z][A-Za-z0-9]*(?:\.[A-Za-z0-9_-]+)?(?:\s[^>]*>|\/?>)\s*\z/
      # Reference definition: [label]: url "title"
      REFERENCE_DEF_REGEXP = /\A {0,3}\[((?:\\.|[^\]])+)\]:/
      FOOTNOTE_DEF_REGEXP = /\A {0,3}\[\^([^\]]+)\]:\s*(.*?)\s*$/
      MATH_BLOCK_REGEXP = /\A {0,3}\$\$\s*$/

      def initialize(options = {})
        @options = options
        @dialect = Dialect.resolve(options[:dialect])
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

        parse_front_matter(state) ||
          parse_blank_line(state) ||
          parse_atx_heading(state) ||
          parse_directive(state) ||
          parse_math_block(state) ||
          parse_fence(state) ||
          parse_hr(state) ||
          parse_blockquote(state) ||
          parse_bullet_list(state) ||
          parse_ordered_list(state) ||
          parse_table(state) ||
          parse_html_block(state) ||
          parse_footnote_definition(state) ||
          parse_reference_definition(state) ||
          parse_code_block(state) ||
          parse_setext_heading(state) ||
          parse_paragraph(state)
      end

      def parse_directive(state)
        line = state.current_line
        match = line.match(/\A {0,3}:::([A-Za-z][\w-]*)(?:\s+(.*?))?\s*\z/)
        return false unless match

        closing_line = find_directive_closing_line(state, match[1])
        return false unless closing_line

        start_line = state.line
        content = state.raw_lines[start_line..closing_line].join("\n")
        content += "\n" if closing_line < state.lines.length - 1 || state.src.end_with?("\n")
        state.tokens << Token.new(
          type: :directive,
          content: content,
          meta: { name: match[1], title: match[2] },
          map: [start_line, closing_line + 1]
        )
        state.line = closing_line + 1
        true
      end

      def parse_math_block(state)
        return false unless state.current_line.match?(MATH_BLOCK_REGEXP)

        start_line = state.line
        content_lines = [state.current_line]
        state.next_line
        until state.eof?
          content_lines << state.raw_line
          state.next_line
          break if content_lines.last.match?(MATH_BLOCK_REGEXP)
        end

        state.tokens << Token.new(
          type: :math_block,
          content: content_lines.join("\n") + "\n",
          map: [start_line, state.line]
        )
        true
      end

      def parse_table(state)
        return false unless @dialect.feature?(:tables)
        return false unless table_delimiter?(state.peek_line)
        return false unless state.current_line.include?("|")

        start_line = state.line
        header = split_table_row(state.current_line)
        alignments = split_table_row(state.peek_line).map { |cell| table_alignment(cell) }
        rows = [header]
        state.next_line
        state.next_line

        while !state.eof? && table_row?(state.current_line)
          rows << split_table_row(state.current_line)
          state.next_line
        end

        state.tokens << Token.new(
          type: :table,
          meta: { rows: rows, alignments: alignments },
          map: [start_line, state.line]
        )
        true
      end

      def table_delimiter?(line)
        return false unless line

        cells = split_table_row(line)
        cells.length > 0 && cells.all? { |cell| cell.match?(/\A\s*:?-{3,}:?\s*\z/) }
      end

      def table_row?(line)
        line && line.include?("|") && !line.strip.empty?
      end

      def split_table_row(line)
        value = line.to_s.strip
        value = value[1..] if value.start_with?("|")
        value = value[0...-1] if value.end_with?("|") && !value.end_with?("\\|")
        cells = []
        current = +""
        escaped = false
        value.each_char do |character|
          if character == "|" && !escaped
            cells << current.strip
            current = +""
          else
            current << character
          end
          escaped = character == "\\" && !escaped
          escaped = false if character != "\\"
        end
        cells << current.strip
        cells
      end

      def table_alignment(cell)
        value = cell.strip
        return :center if value.start_with?(":") && value.end_with?(":")
        return :left if value.start_with?(":")
        return :right if value.end_with?(":")

        nil
      end

      def parse_front_matter(state)
        return false unless state.line.zero?

        opener = state.current_line
        format, closing_marker = front_matter_markers(opener)
        return false unless format

        closing_line = state.lines[(state.line + 1)..]&.index do |line|
          line.strip == closing_marker
        end
        return false unless closing_line

        closing_line += state.line + 1
        start_line = state.line
        raw_lines = state.raw_lines[start_line..closing_line]
        payload = state.lines[(start_line + 1)...closing_line].to_a
        return false unless front_matter_payload?(format, payload)

        content = raw_lines.join("\n")
        content += "\n" if closing_line < state.lines.length - 1 || state.src.end_with?("\n")

        state.tokens << Token.new(
          type: :front_matter,
          content: content,
          meta: { format: format, delimiter: closing_marker },
          map: [start_line, closing_line + 1]
        )
        state.line = closing_line + 1
        true
      end

      def front_matter_markers(opener)
        case opener.strip
        when "---"
          [:yaml, "---"]
        when "+++"
          [:toml, "+++"]
        when ";;;"
          [:json, ";;;"]
        when "{"
          [:json, "}"]
        end
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
        content = match[2].to_s.gsub(/\s+#+\s*\z/, "").strip
        content = "" if content.match?(/\A#+\s*\z/)

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
        line = state.current_line
        return false if line.match?(/\A\s*\z/)

        underline_index = state.line + 1
        while underline_index < state.lines.length && !state.blank_line?(underline_index)
          break if state.lines[underline_index].match?(SETEXT_HEADING_REGEXP)
          break if block_boundary?(state.lines[underline_index])

          underline_index += 1
        end
        return false if underline_index >= state.lines.length

        match = state.lines[underline_index].match(SETEXT_HEADING_REGEXP)
        return false unless match

        level = match[1][0] == "=" ? 1 : 2
        content = state.lines[state.line...underline_index].join("\n").strip
        start_line = state.line

        state.tokens << Token.new(
          type: :heading_open,
          tag: "h#{level}",
          nesting: 1,
          level: state.level,
          markup: match[1][0],
          map: [start_line, underline_index + 1]
        )

        state.tokens << Token.new(
          type: :inline,
          content: content,
          level: state.level + 1,
          map: [start_line, underline_index]
        )

        state.tokens << Token.new(
          type: :heading_close,
          tag: "h#{level}",
          nesting: -1,
          level: state.level,
          markup: match[1][0]
        )

        state.line = underline_index + 1
        true
      end

      def parse_fence(state)
        line = state.current_line
        match = fence_match(line)
        return false unless match

        marker = match[1]
        info = match[2].strip

        fence_char = marker[0]
        fence_length = marker.length
        opening_indent = line[/\A */].length
        start_line = state.line
        state.next_line

        content_lines = []
        until state.eof?
          current = state.current_line
          break if state.line == state.lines.length - 1 && current.empty?

          close_match = current.match(/\A {0,3}#{fence_char}{#{fence_length},}\s*\z/)
          if close_match
            state.next_line
            break
          end
          content_lines << strip_fence_indent(state.raw_line, opening_indent)
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

        while !state.eof?
          if state.current_line.match?(BLOCKQUOTE_REGEXP)
            content_lines << state.raw_line.sub(BLOCKQUOTE_REGEXP, "")
            state.next_line
          elsif !state.blank_line? && lazy_blockquote_continuation?(state.current_line)
            content_lines << state.raw_line.sub(/\A\s+/, "")
            state.next_line
          else
            break
          end
        end

        state.tokens << Token.new(
          type: :blockquote_open,
          tag: "blockquote",
          nesting: 1,
          level: state.level,
          markup: ">",
          attrs: alert_attributes(content_lines),
          map: [start_line, state.line]
        )

        content_lines[0] = content_lines[0].sub(/\A\[!(?:NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*/i, "") if alert_attributes(content_lines)[:alert]

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
          attrs: { tight: true },
          map: [start_line, nil]
        )
        list_token_index = state.tokens.length - 1

        state.level += 1
        parse_list_items(state, BULLET_LIST_REGEXP, marker, match[1].length)
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
          attrs: { start: start_num, tight: true },
          map: [start_line, nil]
        )
        list_token_index = state.tokens.length - 1

        state.level += 1
        parse_ordered_list_items(state, delimiter, match[1].length)
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

      def parse_list_items(state, pattern, _marker, base_indent = 0)
        while !state.eof?
          line = state.current_line
          match = line.match(pattern)
          break unless match
          break if line.match?(HR_REGEXP) && match[1].length <= base_indent

          item_start = state.line
          content = line.sub(pattern, "")

          state.tokens << Token.new(
            type: :list_item_open,
            tag: "li",
            nesting: 1,
            level: state.level,
            attrs: task_attributes(content).merge(tight: true),
            map: [item_start, nil]
          )
          item_token_index = state.tokens.length - 1

          state.level += 1
          state.next_line

          content = strip_task_marker(content)

          item_content_lines = [content]
          nested_lines = []
          nested_start_line = state.line
          while !state.eof? && !state.blank_line? && !state.current_line.match?(pattern)
            if nested_lines.any? && state.current_line.match?(/\A\s+/)
              nested_lines << dedent_list_line(state.current_line, base_indent)
              state.next_line
            elsif state.current_line.match?(/\A\s+/)
              item_content_lines << state.raw_line.sub(/\A\s+/, "")
              state.next_line
            else
              break
            end
          end

          while !state.eof? && !state.blank_line?
            nested_match = state.current_line.match(pattern)
            break unless nested_match && nested_match[1].length > base_indent

            nested_lines << dedent_list_line(state.current_line, base_indent)
            state.next_line
            while !state.eof? && !state.blank_line? && !state.current_line.match?(pattern)
              break unless state.current_line.match?(/\A\s+/)

              nested_lines << dedent_list_line(state.current_line, base_indent)
              state.next_line
            end
          end

          loose_content = collect_loose_item_content(state, pattern, base_indent, nested_lines, match[0].length)

          paragraph_content = item_content_lines.join("\n").strip
          if paragraph_content.match?(HR_REGEXP)
            state.tokens << Token.new(type: :hr, tag: "hr", markup: paragraph_content.strip[0], map: [item_start, state.line])
            paragraph_content = ""
          end
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

          append_nested_tokens(state, nested_lines, nested_start_line)
          append_loose_paragraph(state, loose_content, item_start) if loose_content

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

      def parse_ordered_list_items(state, delimiter, base_indent = 0)
        pattern = /\A( {0,3})(\d{1,9})([#{Regexp.escape(delimiter)}])\s+/

        while !state.eof?
          line = state.current_line
          match = line.match(pattern)
          break unless match
          break if line.match?(HR_REGEXP) && match[1].length <= base_indent

          item_start = state.line
          content = line.sub(pattern, "")

          state.tokens << Token.new(
            type: :list_item_open,
            tag: "li",
            nesting: 1,
            level: state.level,
            attrs: task_attributes(content).merge(tight: true),
            map: [item_start, nil]
          )
          item_token_index = state.tokens.length - 1

          state.level += 1
          state.next_line

          content = strip_task_marker(content)

          item_content_lines = [content]
          nested_lines = []
          nested_start_line = state.line
          while !state.eof? && !state.blank_line? && !state.current_line.match?(pattern)
            if nested_lines.any? && state.current_line.match?(/\A\s+/)
              nested_lines << dedent_list_line(state.current_line, base_indent)
              state.next_line
            elsif state.current_line.match?(/\A\s+/)
              item_content_lines << state.raw_line.sub(/\A\s+/, "")
              state.next_line
            else
              break
            end
          end

          while !state.eof? && !state.blank_line?
            nested_match = state.current_line.match(pattern)
            break unless nested_match && nested_match[1].length > base_indent

            nested_lines << dedent_list_line(state.current_line, base_indent)
            state.next_line
            while !state.eof? && !state.blank_line? && !state.current_line.match?(pattern)
              break unless state.current_line.match?(/\A\s+/)

              nested_lines << dedent_list_line(state.current_line, base_indent)
              state.next_line
            end
          end

          loose_content = collect_loose_item_content(state, pattern, base_indent, nested_lines, match[0].length)

          paragraph_content = item_content_lines.join("\n").strip
          if paragraph_content.match?(HR_REGEXP)
            state.tokens << Token.new(type: :hr, tag: "hr", markup: paragraph_content.strip[0], map: [item_start, state.line])
            paragraph_content = ""
          end
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

          append_nested_tokens(state, nested_lines, nested_start_line)
          append_loose_paragraph(state, loose_content, item_start) if loose_content

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

      def dedent_list_line(line, base_indent)
        line[(base_indent + 2)..] || line.lstrip
      end

      def append_nested_tokens(state, nested_lines, start_line)
        return if nested_lines.empty?

        nested_tokens = BlockParser.new(@options).parse(nested_lines.join("\n"))
        nested_tokens.each do |token|
          token.level += state.level
          token.map = token.map.map { |line| line + start_line } if token.map
          state.tokens << token
        end
      end

      def collect_loose_item_content(state, pattern, base_indent, nested_lines = nil, content_indent = base_indent + 2)
        return unless state.blank_line?

        state.skip_blank_lines
        return if state.eof?

        next_match = state.current_line.match(pattern)
        if next_match && next_match[1].length <= base_indent
          mark_current_list_loose(state)
          return
        end
        return unless state.current_line.match?(/\A {#{content_indent},}/)

        mark_current_list_loose(state)
        if state.current_line.match?(/\A {#{base_indent + 4},}/) && nested_lines
          while !state.eof?
            if state.blank_line?
              index = state.line
              index += 1 while index < state.lines.length && state.blank_line?(index)
              break if index >= state.lines.length || !state.lines[index].match?(/\A\s+/)

              nested_lines << ""
              state.next_line
            elsif state.current_line.match?(/\A\s+/)
              nested_lines << dedent_list_line(state.current_line, base_indent)
              state.next_line
            else
              break
            end
          end
          return nil
        end

        content_lines = []
        while !state.eof? && !state.blank_line? && !state.current_line.match?(pattern)
          break unless state.current_line.match?(/\A {#{content_indent},}/)

          content_lines << state.raw_line.sub(/\A\s+/, "")
          state.next_line
        end
        content_lines.join("\n").strip
      end

      def append_loose_paragraph(state, content, start_line)
        return if content.to_s.empty?

        state.tokens << Token.new(type: :paragraph_open, tag: "p", nesting: 1, level: state.level, map: [start_line, state.line])
        state.tokens << Token.new(type: :inline, content: content, level: state.level + 1, map: [start_line, state.line])
        state.tokens << Token.new(type: :paragraph_close, tag: "p", nesting: -1, level: state.level)
      end

      def mark_current_list_loose(state)
        list_index = state.tokens.rindex { |token| %i[bullet_list_open ordered_list_open].include?(token.type) }
        return unless list_index

        state.tokens[list_index].attrs[:tight] = false
        state.tokens[(list_index + 1)..].to_a.reverse_each do |token|
          break if %i[bullet_list_open ordered_list_open].include?(token.type)
          token.attrs[:tight] = false if token.type == :list_item_open
        end
      end

      def parse_html_block(state)
        line = state.current_line

        return false unless html_block_start?(line)

        start_line = state.line
        content_lines = []

        if line.match?(HTML_BLOCK_START_2)
          until state.eof?
            current_line = state.current_line
            content_lines << current_line
            state.next_line
            break if current_line.include?("-->")
          end
        elsif line.match?(HTML_BLOCK_START_1)
          tag = line[/\A {0,3}<([A-Za-z][A-Za-z0-9]*)/i, 1]
          until state.eof?
            current_line = state.current_line
            content_lines << state.raw_line
            state.next_line
            break if current_line.match?(%r{</#{Regexp.escape(tag)}\s*>}i)
          end
        elsif line.match?(HTML_BLOCK_START_3)
          until state.eof?
            current_line = state.current_line
            content_lines << state.raw_line
            state.next_line
            break if current_line.include?("?>")
          end
        elsif line.match?(HTML_BLOCK_START_5)
          until state.eof?
            current_line = state.current_line
            content_lines << state.raw_line
            state.next_line
            break if current_line.include?("]]>")
          end
        else
          until state.eof?
            current_line = state.current_line
            content_lines << state.raw_line
            state.next_line
            break if line.match?(HTML_BLOCK_START_7) && current_line.match?(%r{</[A-Z][A-Za-z0-9]*(?:\.[A-Za-z0-9_-]+)?>})
            break if state.blank_line?
          end
        end

        state.tokens << Token.new(
          type: :html_block,
          content: content_lines.join("\n") + "\n",
          map: [start_line, state.line]
        )

        true
      end

      def html_block_start?(line)
        [HTML_BLOCK_START_1, HTML_BLOCK_START_2, HTML_BLOCK_START_3, HTML_BLOCK_START_4,
         HTML_BLOCK_START_5, HTML_BLOCK_START_6, HTML_BLOCK_START_7].any? { |pattern| line.match?(pattern) }
      end

      def lazy_blockquote_continuation?(line)
        !line.match?(ATX_HEADING_REGEXP) && !fence_match(line) && !line.match?(HR_REGEXP) &&
          !line.match?(BLOCKQUOTE_REGEXP) && !line.match?(BULLET_LIST_REGEXP) &&
          !line.match?(ORDERED_LIST_REGEXP) && !html_block_start?(line) &&
          !line.match?(REFERENCE_DEF_REGEXP) && !line.match?(FOOTNOTE_DEF_REGEXP)
      end

      def parse_code_block(state)
        return false unless state.current_line.match?(CODE_BLOCK_INDENT)

        start_line = state.line
        content_lines = []

        while !state.eof?
          if state.current_line.match?(CODE_BLOCK_INDENT)
            content_lines << strip_code_indent(state.raw_line, state.current_line)
            state.next_line
          elsif state.blank_line? && state.line < state.lines.length - 1
            content_lines << ""
            state.next_line
          else
            break
          end
        end
        content_lines.pop while content_lines.last == ""

        state.tokens << Token.new(
          type: :code_block,
          tag: "code",
          content: content_lines.join("\n") + "\n",
          map: [start_line, state.line]
        )

        true
      end

      def parse_reference_definition(state)
        line = state.raw_line
        match = line.match(REFERENCE_DEF_REGEXP)
        return false unless match

        label = normalize_reference_label(match[1])
        tail = line[match[0].length..].to_s.strip
        parsed = parse_reference_tail(tail)
        consumed = 1

        if parsed.nil? && tail.empty?
          url_line = state.peek_line
          return false if url_line.nil? || state.blank_line?(state.line + 1)

          parsed = parse_reference_tail(url_line.to_s.strip)
          consumed += 1 if parsed
        end
        if parsed && parsed[1].nil?
          title_line = state.peek_line(consumed)
          if title_line && !state.blank_line?(state.line + consumed) && title_line.match?(/\A\s+/)
            title = parse_reference_title(title_line.to_s.strip)
            parsed = [parsed[0], title] if title
            consumed += 1 if title
          end
        end
        return false unless parsed

        url, title = parsed

        state.tokens << Token.new(
          type: :reference_definition,
          attrs: {
            label: label,
            url: url,
            title: title
          }.compact,
          map: [state.line, state.line + 1]
        )

        state.line += consumed
        true
      end

      def reference_definition_candidate?(state)
        match = state.raw_line.match(REFERENCE_DEF_REGEXP)
        return false unless match

        tail = state.raw_line[match[0].length..].to_s.strip
        return true if parse_reference_tail(tail)
        return false unless tail.empty?

        next_line = state.peek_line
        next_line && !state.blank_line?(state.line + 1) && parse_reference_tail(next_line.to_s.strip)
      end

      def normalize_reference_label(label)
        label.to_s.gsub(/\\([!"#$%&'()*+,\-.\/:;<=>?@\[\\\]^_`{|}~])/, '\\1').gsub(/\s+/, " ").strip.downcase
      end

      def parse_reference_tail(tail)
        value = tail.to_s
        return nil if value.empty?

        if value.start_with?("<")
          closing = value.index(">", 1)
          return nil unless closing

          url = value[1...closing]
          raw_remainder = value[(closing + 1)..].to_s
          return nil unless raw_remainder.empty? || raw_remainder.match?(/\A\s/)

          remainder = raw_remainder.strip
        else
          index = 0
          depth = 0
          while index < value.length
            character = value[index]
            if character == "\\"
              index += 2
              next
            end
            if character == "("
              depth += 1
            elsif character == ")"
              break if depth.zero?

              depth -= 1
            elsif character.match?( /\s/ ) && depth.zero?
              break
            end
            index += 1
          end
          return nil if index.zero?

          url = value[0...index]
          remainder = value[index..].to_s.strip
        end

        return [url, nil] if remainder.empty?

        title = parse_reference_title(remainder)
        title ? [url, title] : nil
      end

      def parse_reference_title(value)
        return nil unless value.length >= 2

        opener = value[0]
        closer = { '"' => '"', "'" => "'", "(" => ")" }[opener]
        return nil unless closer && value.end_with?(closer)

        value[1...-1]
      end

      def parse_footnote_definition(state)
        match = state.current_line.match(FOOTNOTE_DEF_REGEXP)
        return false unless match

        start_line = state.line
        raw_lines = [state.current_line]
        content = match[2]
        state.next_line
        while !state.eof? && state.current_line.match?(/\A {4}/)
          raw_lines << state.current_line
          content = "#{content}\n#{state.current_line.sub(/\A {4}/, "")}"
          state.next_line
        end

        state.tokens << Token.new(
          type: :footnote_definition,
          content: raw_lines.join("\n") + "\n",
          attrs: { label: match[1].downcase, content: content },
          map: [start_line, state.line]
        )
        true
      end

      def parse_paragraph(state)
        return false if state.blank_line?

        start_line = state.line
        content_lines = []

        while !state.eof? && !state.blank_line?
          line = state.current_line
          break if line.match?(ATX_HEADING_REGEXP) ||
                   line.match?(MATH_BLOCK_REGEXP) ||
                   fence_match(line) ||
                   line.match?(HR_REGEXP) ||
                   line.match?(BLOCKQUOTE_REGEXP) ||
                   line.match?(BULLET_LIST_REGEXP) ||
                   line.match?(ORDERED_LIST_REGEXP) ||
                   (html_block_start?(line) && !line.match?(HTML_BLOCK_START_7)) ||
                   (reference_definition_candidate?(state) && content_lines.empty?) ||
                   line.match?(FOOTNOTE_DEF_REGEXP)

          if state.peek_line&.match?(SETEXT_HEADING_REGEXP)
            break if content_lines.any?
          end

          content_lines << if content_lines.empty?
                             state.raw_line.sub(/\A {0,3}/, "")
                           else
                             state.raw_line.sub(/\A\s+/, "")
                           end
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
          content: content_lines.join("\n").strip.gsub(/(?<! ) \n/, "\n"),
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

      def alert_attributes(content_lines)
        match = content_lines.first.to_s.match(/\A\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*/i)
        match ? { alert: match[1].downcase } : {}
      end

      def block_boundary?(line)
        line.match?(ATX_HEADING_REGEXP) || fence_match(line) ||
          line.match?(HR_REGEXP) || line.match?(BLOCKQUOTE_REGEXP) ||
          line.match?(BULLET_LIST_REGEXP) || line.match?(ORDERED_LIST_REGEXP) ||
          line.match?(REFERENCE_DEF_REGEXP) || line.match?(FOOTNOTE_DEF_REGEXP)
      end

      def find_directive_closing_line(state, name)
        depth = 1
        index = state.line + 1
        while index < state.lines.length
          candidate = state.lines[index]
          nested = candidate.match(/\A {0,3}:::([A-Za-z][\w-]*)(?:\s+.*)?\s*\z/)
          if nested
            depth += 1
          elsif candidate.strip == ":::"
            depth -= 1
            return index if depth.zero?
          end
          index += 1
        end
        nil
      end

      def strip_code_indent(raw_line, expanded_line)
        return raw_line unless expanded_line.start_with?("    ")

        consumed = 0
        index = 0
        raw_line.each_char do |character|
          break if consumed >= 4

          consumed += character == "\t" ? 4 - (consumed % 4) : 1
          index += 1
        end
        raw_line[index..] || ""
      end

      def fence_match(line)
        match = line.to_s.match(FENCE_OPEN_REGEXP)
        return unless match
        return if match[1].start_with?("`") && match[2].include?("`")

        match
      end

      def front_matter_payload?(format, lines)
        return false if lines.empty? || lines.all? { |line| line.strip.empty? }

        case format
        when :yaml
          lines.any? { |line| line.match?(/\A\s*[^#\s][^:]*:/) }
        when :toml
          lines.any? { |line| line.match?(/\A\s*[^#\s=]+\s*=/) }
        when :json
          lines.join.match?(/[{}\[\]]|\A\s*\"[^\"]+\"\s*:/)
        else
          false
        end
      end

      def strip_fence_indent(raw_line, indent)
        return raw_line if indent.zero?

        raw_line.sub(/\A {0,#{indent}}/, "")
      end

      def task_attributes(content)
        return {} unless @dialect.feature?(:task_lists)

        match = content.match(/\A\[([ xX])\]\s+/)
        return {} unless match

        { task: true, checked: match[1].downcase == "x" }
      end

      def strip_task_marker(content)
        return content unless @dialect.feature?(:task_lists)

        content.sub(/\A\[[ xX]\]\s+/, "")
      end
    end
  end
end
