# frozen_string_literal: true

require_relative "../dialect"

module Mdlint
  module Parser
    class InlineParser
      ESCAPE_CHARS = '!"#$%&\'()*+,\\-./:;<=>?@[\\\\\\]^_`{|}~'
      ESCAPE_REGEXP = /\\([#{Regexp.escape(ESCAPE_CHARS)}])/
      BACKTICK_REGEXP = /(`+)(.+?)\1(?!`)/
      AUTOLINK_REGEXP = %r{<(([A-Za-z][A-Za-z0-9+.-]{1,31}):[^\s<>]+)>}
      EMAIL_AUTOLINK_REGEXP = /<([a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)>/
      HTML_INLINE_REGEXP = %r{</?[a-zA-Z][a-zA-Z0-9:-]*(?:\s+[^>]*)?/?>}

      def initialize(options = {})
        @options = options
        @dialect = Dialect.resolve(options[:dialect])
      end

      def parse(content)
        tokens = []
        parse_inline(content, tokens)
        tokens
      end

      def parse_inline(content, tokens)
        pos = 0
        text_buffer = ""

        while pos < content.length
          remaining = content[pos..]

          if (match = remaining.match(/\A\[\^([^\]]+)\]/))
            flush_text(text_buffer, tokens)
            text_buffer = ""
            tokens << Token.new(type: :footnote_ref, attrs: { label: match[1].downcase })
            pos += match[0].length
          elsif (match = remaining.match(/\A\$([^$\n]+)\$/))
            flush_text(text_buffer, tokens)
            text_buffer = ""
            tokens << Token.new(type: :math_inline, content: match[1])
            pos += match[0].length
          elsif remaining.start_with?("\\\n")
            flush_text(text_buffer, tokens)
            text_buffer = ""
            tokens << Token.new(type: :hardbreak, tag: "br")
            pos += 2
          elsif (match = remaining.match(/\A#{ESCAPE_REGEXP}/))
            flush_text(text_buffer, tokens)
            text_buffer = ""
            tokens << Token.new(type: :text, content: match[1])
            pos += match[0].length
          elsif remaining.start_with?("![")
            if (match = inline_link_match(remaining, image: true))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              tokens << Token.new(
                type: :image,
                tag: "img",
                attrs: {
                  src: match[:url],
                  alt: match[:text],
                  title: match[:title]
                }.compact,
                content: match[:text]
              )
              pos += match[:length]
            elsif (match = remaining.match(/\A!\[([^\]]*)\]\[([^\]]*)\]/))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              label = match[2].empty? ? match[1] : match[2]
              tokens << Token.new(
                type: :image,
                tag: "img",
                attrs: { reference_label: label.downcase, reference_kind: :full, alt: match[1] },
                content: match[1],
                markup: "reference"
              )
              pos += match[0].length
            elsif (match = remaining.match(/\A!\[([^\]]+)\](?!\()/))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              tokens << Token.new(
                type: :image,
                tag: "img",
                attrs: { reference_label: match[1].downcase, reference_kind: :shortcut, alt: match[1] },
                content: match[1],
                markup: "reference"
              )
              pos += match[0].length
            else
              text_buffer += remaining[0]
              pos += 1
            end
          elsif remaining.start_with?("[")
            # Inline link: [text](url "title")
            if (match = inline_link_match(remaining))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              tokens << Token.new(
                type: :link_open,
                tag: "a",
                nesting: 1,
                attrs: {
                  href: match[:url],
                  title: match[:title]
                }.compact
              )
              parse_inline(match[:text], tokens)
              tokens << Token.new(
                type: :link_close,
                tag: "a",
                nesting: -1
              )
              pos += match[:length]
            # Full reference link: [text][label]
            elsif (match = remaining.match(/\A\[([^\]]*)\]\[([^\]]*)\]/))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              label = match[2].empty? ? match[1] : match[2]
              tokens << Token.new(
                type: :link_open,
                tag: "a",
                nesting: 1,
                attrs: { reference_label: label.downcase, reference_kind: :full },
                markup: "reference"
              )
              parse_inline(match[1], tokens)
              tokens << Token.new(
                type: :link_close,
                tag: "a",
                nesting: -1,
                markup: "reference"
              )
              pos += match[0].length
            # Shortcut reference link: [label]
            elsif (match = remaining.match(/\A\[([^\[\]]+)\](?!\(|\[)/))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              label = match[1]
              tokens << Token.new(
                type: :link_open,
                tag: "a",
                nesting: 1,
                attrs: { reference_label: label.downcase, reference_kind: :shortcut },
                markup: "reference"
              )
              tokens << Token.new(type: :text, content: label)
              tokens << Token.new(
                type: :link_close,
                tag: "a",
                nesting: -1,
                markup: "reference"
              )
              pos += match[0].length
            else
              text_buffer += remaining[0]
              pos += 1
            end
          elsif remaining.start_with?("`")
            if (match = code_span_match(remaining))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              code_content = match[:content]
              code_content = code_content.gsub(/\r?\n/, " ")
              if code_content.start_with?(" ") && code_content.end_with?(" ") && !code_content.match?(/\A +\z/)
                code_content = code_content[1...-1]
              end
              tokens << Token.new(
                type: :code_inline,
                tag: "code",
                content: code_content,
                markup: match[:delimiter]
              )
              pos += match[:length]
            else
              text_buffer += remaining[0]
              pos += 1
            end
          elsif remaining.start_with?("**")
            if (match = emphasis_match(remaining, "**", previous: pos.zero? ? nil : content[pos - 1], strong: true))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              tokens << Token.new(type: :strong_open, tag: "strong", nesting: 1, markup: "**")
              parse_inline(match[1], tokens)
              tokens << Token.new(type: :strong_close, tag: "strong", nesting: -1, markup: "**")
              pos += match[0].length
            else
              text_buffer += remaining[0]
              pos += 1
            end
          elsif remaining.start_with?("__")
            if (match = emphasis_match(remaining, "__", previous: pos.zero? ? nil : content[pos - 1], strong: true))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              tokens << Token.new(type: :strong_open, tag: "strong", nesting: 1, markup: "__")
              parse_inline(match[1], tokens)
              tokens << Token.new(type: :strong_close, tag: "strong", nesting: -1, markup: "__")
              pos += match[0].length
            else
              text_buffer += remaining[0]
              pos += 1
            end
          elsif @dialect.feature?(:strikethrough) && remaining.start_with?("~~")
            if (match = remaining.match(/\A~~(?!\s)(.+?)(?<!\s)~~/m))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              tokens << Token.new(type: :s_open, tag: "del", nesting: 1, markup: "~~")
              parse_inline(match[1], tokens)
              tokens << Token.new(type: :s_close, tag: "del", nesting: -1, markup: "~~")
              pos += match[0].length
            else
              text_buffer += remaining[0]
              pos += 1
            end
          elsif remaining.start_with?("*")
            if (match = emphasis_match(remaining, "*", previous: pos.zero? ? nil : content[pos - 1]))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              tokens << Token.new(type: :em_open, tag: "em", nesting: 1, markup: "*")
              parse_inline(match[1], tokens)
              tokens << Token.new(type: :em_close, tag: "em", nesting: -1, markup: "*")
              pos += match[0].length
            else
              text_buffer += remaining[0]
              pos += 1
            end
          elsif remaining.start_with?("_")
            if (match = emphasis_match(remaining, "_", previous: pos.zero? ? nil : content[pos - 1]))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              tokens << Token.new(type: :em_open, tag: "em", nesting: 1, markup: "_")
              parse_inline(match[1], tokens)
              tokens << Token.new(type: :em_close, tag: "em", nesting: -1, markup: "_")
              pos += match[0].length
            else
              text_buffer += remaining[0]
              pos += 1
            end
          elsif remaining.start_with?("<")
            if (match = remaining.match(/\A#{AUTOLINK_REGEXP}/))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              tokens << Token.new(
                type: :link_open,
                tag: "a",
                nesting: 1,
                attrs: { href: match[1] },
                markup: "autolink"
              )
              tokens << Token.new(type: :text, content: match[1])
              tokens << Token.new(
                type: :link_close,
                tag: "a",
                nesting: -1,
                markup: "autolink"
              )
              pos += match[0].length
            elsif (match = remaining.match(/\A#{EMAIL_AUTOLINK_REGEXP}/))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              tokens << Token.new(
                type: :link_open,
                tag: "a",
                nesting: 1,
                attrs: { href: "mailto:#{match[1]}" },
                markup: "autolink"
              )
              tokens << Token.new(type: :text, content: match[1])
              tokens << Token.new(
                type: :link_close,
                tag: "a",
                nesting: -1,
                markup: "autolink"
              )
              pos += match[0].length
            elsif (match = remaining.match(/\A#{HTML_INLINE_REGEXP}/))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              tokens << Token.new(type: :html_inline, content: match[0])
              pos += match[0].length
            else
              text_buffer += remaining[0]
              pos += 1
            end
          elsif @dialect.feature?(:bare_autolinks) && (match = remaining.match(/\A((?:https?|ftp):\/\/[^\s<]+)/))
            flush_text(text_buffer, tokens)
            text_buffer = ""
            href = match[1].sub(/[.,!?;:]\z/, "")
            consumed = href.length
            tokens << Token.new(
              type: :link_open,
              tag: "a",
              nesting: 1,
              attrs: { href: href },
              markup: "autolink"
            )
            tokens << Token.new(type: :text, content: href)
            tokens << Token.new(type: :link_close, tag: "a", nesting: -1, markup: "autolink")
            pos += consumed
          elsif (match = remaining.match(/\A {2,}\n/))
            flush_text(text_buffer, tokens)
            text_buffer = ""
            tokens << Token.new(type: :hardbreak, tag: "br")
            pos += match[0].length
          elsif remaining[0] == "\n"
            flush_text(text_buffer, tokens)
            text_buffer = ""
            tokens << Token.new(type: :softbreak)
            pos += 1
          else
            text_buffer += remaining[0]
            pos += 1
          end
        end

        flush_text(text_buffer, tokens)
      end

      private

      def inline_link_match(value, image: false)
        prefix = image ? "![" : "["
        return unless value.start_with?(prefix)

        depth = 1
        index = prefix.length
        while index < value.length
          if value[index] == "\\"
            index += 2
            next
          end
          if value[index] == "`" && (code = code_span_match(value[index..]))
            index += code[:length]
            next
          end
          if value[index] == "["
            depth += 1
          elsif value[index] == "]"
            depth -= 1
            break if depth.zero?
          end
          index += 1
        end
        return unless depth.zero? && value[index + 1] == "("

        destination = parse_link_destination(value[(index + 2)..])
        return unless destination

        {
          text: value[prefix.length...index],
          url: destination[:url],
          title: destination[:title],
          length: index + 2 + destination[:length]
        }
      end

      def parse_link_destination(value)
        index = 0
        index += 1 while index < value.length && value[index].match?(/\s/)
        return { url: "", title: nil, length: index + 1 } if value[index] == ")"

        if value[index] == "<"
          closing = find_unescaped(value, ">", index + 1)
          return unless closing

          url = value[(index + 1)...closing]
          return if url.match?(/[\r\n]/)
          index = closing + 1
        else
          start = index
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
            elsif character.match?(/\s/) && depth.zero?
              break
            end
            index += 1
          end
          return if index == start

          url = value[start...index]
        end

        whitespace = index
        index += 1 while index < value.length && value[index].match?(/\s/)
        return { url: url, title: nil, length: index + 1 } if value[index] == ")"
        return unless index > whitespace

        title_start = value[index]
        title_end = { '"' => '"', "'" => "'", "(" => ")" }[title_start]
        return unless title_end

        closing = find_unescaped(value, title_end, index + 1)
        return unless closing
        remainder = closing + 1
        remainder += 1 while remainder < value.length && value[remainder].match?(/\s/)
        return unless value[remainder] == ")"

        { url: url, title: value[(index + 1)...closing], length: remainder + 1 }
      end

      def find_unescaped(value, character, start)
        index = start
        while index < value.length
          return index if value[index] == character && (index.zero? || value[index - 1] != "\\")

          index += 1
        end
        nil
      end

      def code_span_match(value)
        opening = value[/\A`+/]
        return unless opening

        delimiter = opening
        search = delimiter.length
        while (closing = value.index(delimiter, search))
          run = value[closing..].match(/\A`+/)[0].length
          if run == delimiter.length
            return { delimiter: delimiter, content: value[delimiter.length...closing], length: closing + delimiter.length }
          end
          search = closing + run
        end
        nil
      end

      def emphasis_match(value, delimiter, previous:, strong: false)
        escaped = Regexp.escape(delimiter)
        match = value.match(/\A#{escaped}(?!\s)(.+?)(?<!\s)#{escaped}/m)
        return unless match

        opening_next = match[1][0]
        closing_previous = match[1][-1]
        after = value[match[0].length]
        return unless delimiter_open?(delimiter, previous, opening_next)
        return unless delimiter_close?(delimiter, closing_previous, after)

        match
      end

      def delimiter_open?(delimiter, before, after)
        before_space = whitespace_character?(before)
        after_space = whitespace_character?(after)
        before_punctuation = punctuation_character?(before)
        after_punctuation = punctuation_character?(after)
        left_flanking = !after_space && (!after_punctuation || before_space || before_punctuation)
        right_flanking = !before_space && (!before_punctuation || after_space || after_punctuation)

        delimiter.start_with?("_") ? left_flanking && (!right_flanking || before_punctuation || before_space) : left_flanking
      end

      def delimiter_close?(delimiter, before, after)
        before_space = whitespace_character?(before)
        after_space = whitespace_character?(after)
        before_punctuation = punctuation_character?(before)
        after_punctuation = punctuation_character?(after)
        left_flanking = !after_space && (!after_punctuation || before_space || before_punctuation)
        right_flanking = !before_space && (!before_punctuation || after_space || after_punctuation)

        delimiter.start_with?("_") ? right_flanking && (!left_flanking || after_punctuation || after_space) : right_flanking
      end

      def whitespace_character?(character)
        character.nil? || character.match?(/\s|\p{Space}/u)
      end

      def punctuation_character?(character)
        !character.nil? && character.match?(/[[:punct:]]/u)
      end

      def flush_text(buffer, tokens)
        return if buffer.empty?

        tokens << Token.new(type: :text, content: buffer)
      end
    end
  end
end
