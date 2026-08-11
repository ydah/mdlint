# frozen_string_literal: true

require_relative "../dialect"

module Mdlint
  module Parser
    class InlineParser
      ESCAPE_CHARS = '!"#$%&\'()*+,\\-./:;<=>?@[\\\\\\]^_`{|}~'
      ESCAPE_REGEXP = /\\([#{Regexp.escape(ESCAPE_CHARS)}])/
      BACKTICK_REGEXP = /(`+)(.+?)\1(?!`)/
      AUTOLINK_REGEXP = %r{<((?:https?|ftp)://[^>]+)>}
      EMAIL_AUTOLINK_REGEXP = /<([a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)>/
      HTML_INLINE_REGEXP = %r{</?[a-zA-Z][a-zA-Z0-9]*(?:\s+[^>]*)?>}

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
            if (match = remaining.match(/\A!\[([^\]]*)\]\(([^)\s]*)(?:\s+"([^"]*)")?\)/))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              tokens << Token.new(
                type: :image,
                tag: "img",
                attrs: {
                  src: match[2],
                  alt: match[1],
                  title: match[3]
                }.compact,
                content: match[1]
              )
              pos += match[0].length
            elsif (match = remaining.match(/\A!\[([^\]]*)\]\[([^\]]*)\]/))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              label = match[2].empty? ? match[1] : match[2]
              tokens << Token.new(
                type: :image,
                tag: "img",
                attrs: { reference_label: label.downcase, alt: match[1] },
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
                attrs: { reference_label: match[1].downcase, alt: match[1] },
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
            if (match = remaining.match(/\A\[([^\]]*)\]\(([^)\s]*)(?:\s+"([^"]*)")?\)/))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              tokens << Token.new(
                type: :link_open,
                tag: "a",
                nesting: 1,
                attrs: {
                  href: match[2],
                  title: match[3]
                }.compact
              )
              parse_inline(match[1], tokens)
              tokens << Token.new(
                type: :link_close,
                tag: "a",
                nesting: -1
              )
              pos += match[0].length
            # Full reference link: [text][label]
            elsif (match = remaining.match(/\A\[([^\]]*)\]\[([^\]]*)\]/))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              label = match[2].empty? ? match[1] : match[2]
              tokens << Token.new(
                type: :link_open,
                tag: "a",
                nesting: 1,
                attrs: { reference_label: label.downcase },
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
            elsif (match = remaining.match(/\A\[([^\]]+)\](?!\(|\[)/))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              label = match[1]
              tokens << Token.new(
                type: :link_open,
                tag: "a",
                nesting: 1,
                attrs: { reference_label: label.downcase },
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
            if (match = remaining.match(/\A(`+)(.+?)\1(?!`)/m))
              flush_text(text_buffer, tokens)
              text_buffer = ""
              code_content = match[2]
              code_content = code_content.strip if code_content.start_with?(" ") && code_content.end_with?(" ")
              tokens << Token.new(
                type: :code_inline,
                tag: "code",
                content: code_content,
                markup: match[1]
              )
              pos += match[0].length
            else
              text_buffer += remaining[0]
              pos += 1
            end
          elsif remaining.start_with?("**")
            if (match = remaining.match(/\A\*\*(?!\s)(.+?)(?<!\s)\*\*/m))
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
            if (match = remaining.match(/\A__(?!\s)(.+?)(?<!\s)__/m))
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
            if (match = remaining.match(/\A\*(?!\s)(.+?)(?<!\s)\*/m))
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
            if (match = remaining.match(/\A_(?!\s)(.+?)(?<!\s)_/m))
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
          elsif remaining.start_with?("  \n")
            flush_text(text_buffer, tokens)
            text_buffer = ""
            tokens << Token.new(type: :hardbreak, tag: "br")
            pos += 3
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

      def flush_text(buffer, tokens)
        return if buffer.empty?

        tokens << Token.new(type: :text, content: buffer)
      end
    end
  end
end
