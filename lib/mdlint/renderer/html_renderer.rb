# frozen_string_literal: true

require "cgi"
require "uri"

module Mdlint
  module Renderer
    class HtmlRenderer
      NAMED_ENTITIES = {
        "amp" => "&", "apos" => "'", "gt" => ">", "lt" => "<", "quot" => '"',
        "nbsp" => "\u00a0", "copy" => "©", "reg" => "®", "trade" => "™",
        "AElig" => "Æ", "aelig" => "æ", "Dcaron" => "Ď", "dcaron" => "ď",
        "ouml" => "ö", "Ouml" => "Ö", "uuml" => "ü", "Uuml" => "Ü",
        "frac12" => "½", "frac14" => "¼", "frac34" => "¾", "HilbertSpace" => "ℋ",
        "DifferentialD" => "ⅆ", "ClockwiseContourIntegral" => "∲", "ngE" => "≧̸"
      }.freeze

      def initialize(options = {})
        @options = options
        @reference_definitions = {}
      end

      def render(tokens)
        @reference_definitions = {}
        collect_reference_definitions(tokens)
        render_sequence(tokens, 0).first
      end

      private

      def render_sequence(tokens, index, closing_type = nil)
        output = +""
        while index < tokens.length
          token = tokens[index]
          if closing_type && token.type == closing_type
            return [output, index + 1]
          end

          case token.type
          when :heading_open
            content, index = render_until_inline(tokens, index + 1, :heading_close)
            output << "<#{token.tag}>#{render_inline(content)}</#{token.tag}>\n"
          when :paragraph_open
            content, index = render_until_inline(tokens, index + 1, :paragraph_close)
            output << "<p>#{render_inline(content)}</p>\n"
          when :bullet_list_open, :ordered_list_open
            list, index = render_sequence(tokens, index + 1, token.type == :bullet_list_open ? :bullet_list_close : :ordered_list_close)
            tag = token.type == :bullet_list_open ? "ul" : "ol"
            output << "<#{tag}>\n#{list}</#{tag}>\n"
          when :list_item_open
            item, index = render_sequence(tokens, index + 1, :list_item_close)
            task = token.attrs[:task] ? task_checkbox(token.attrs[:checked]) : ""
            output << "<li>#{task}#{item}</li>\n"
          when :blockquote_open
            content, index = render_sequence(tokens, index + 1, :blockquote_close)
            if token.attrs[:alert]
              alert = escape_attribute(token.attrs[:alert])
              output << "<aside class=\"markdown-alert markdown-alert-#{alert}\">\n#{content}</aside>\n"
            else
              output << "<blockquote>\n#{content}</blockquote>\n"
            end
          when :fence
            output << fenced_code(token)
            index += 1
          when :code_block
            output << "<pre><code>#{escape_raw(token.content)}</code></pre>\n"
            index += 1
          when :math_block
            output << "<div class=\"math-block\">#{escape_raw(token.content)}</div>\n"
            index += 1
          when :footnote_definition
            label = escape_attribute(token.attrs[:label])
            content = escape(token.attrs[:content])
            output << "<div class=\"footnote\" id=\"fn-#{label}\"><sup>#{label}</sup> #{content}</div>\n"
            index += 1
          when :hr
            output << "<hr />\n"
            index += 1
          when :html_block
            output << token.content
            output << "\n" unless token.content.end_with?("\n")
            index += 1
          when :table
            output << render_table(token)
            index += 1
          when :directive
            output << render_directive(token)
            index += 1
          when :front_matter, :reference_definition
            index += 1
          else
            index += 1
          end
        end

        [output, index]
      end

      def render_until_inline(tokens, index, closing_type)
        inline = tokens[index..]&.find { |token| token.type == :inline }
        closing_index = tokens[index..]&.index { |token| token.type == closing_type }
        [inline, index + (closing_index || 0) + 1]
      end

      def render_inline(token)
        return "" unless token
        return escape(token.content) if token.children.empty?

        render_inline_tokens(token.children)
      end

      def render_inline_tokens(tokens)
        output = +""
        index = 0
        while index < tokens.length
          token = tokens[index]
          case token.type
          when :text
            output << escape(token.content)
          when :strong_open, :em_open, :s_open
            close_type = { strong_open: :strong_close, em_open: :em_close, s_open: :s_close }.fetch(token.type)
            tag = { strong_open: "strong", em_open: "em", s_open: "del" }.fetch(token.type)
            close_index = find_close(tokens, index, close_type)
            output << "<#{tag}>#{render_inline_tokens(tokens[(index + 1)...close_index])}</#{tag}>"
            index = close_index
          when :code_inline
            output << "<code>#{escape_raw(token.content.strip)}</code>"
          when :math_inline
            output << "<span class=\"math-inline\">#{escape(token.content)}</span>"
          when :footnote_ref
            label = escape_attribute(token.attrs[:label])
            output << "<sup><a href=\"#fn-#{label}\">#{label}</a></sup>"
          when :link_open
            close_index = find_close(tokens, index, :link_close)
            reference = @reference_definitions[token.attrs[:reference_label]]
            href = token.attrs[:href] || reference&.fetch(:url, "") || ""
            title = token.attrs[:title] || reference&.fetch(:title, nil)
            title_attribute = title ? " title=\"#{escape_attribute(title)}\"" : ""
            output << "<a href=\"#{escape_url_attribute(href)}\"#{title_attribute}>#{render_inline_tokens(tokens[(index + 1)...close_index])}</a>"
            index = close_index
          when :image
            attrs = "src=\"#{escape_url_attribute(token.attrs[:src])}\" alt=\"#{escape_attribute(token.attrs[:alt] || token.content)}\""
            attrs += " title=\"#{escape_attribute(token.attrs[:title])}\"" if token.attrs[:title]
            output << "<img #{attrs}>"
          when :softbreak
            output << "\n"
          when :hardbreak
            output << "<br />\n"
          when :html_inline
            output << token.content
          end
          index += 1
        end
        output
      end

      def render_table(token)
        rows = token.meta.fetch(:rows, [])
        return "" if rows.empty?

        header = rows.first.map { |cell| "<th>#{render_cell(cell)}</th>" }.join
        body = rows.drop(1).map do |row|
          cells = row.map { |cell| "<td>#{render_cell(cell)}</td>" }.join
          "<tr>#{cells}</tr>\n"
        end.join
        "<table>\n<thead><tr>#{header}</tr></thead>\n<tbody>\n#{body}</tbody>\n</table>\n"
      end

      def collect_reference_definitions(tokens)
        tokens.each do |token|
          next unless token.type == :reference_definition

          label = token.attrs[:label]
          @reference_definitions[label] ||= {
            url: token.attrs[:url],
            title: token.attrs[:title]
          }
        end
      end

      def render_directive(token)
        name = token.meta[:name].to_s.downcase
        return token.content unless %w[note tip important warning caution message details].include?(name)

        lines = token.content.gsub(/\r\n/, "\n").split("\n", -1)
        lines.shift
        lines.pop while lines.last.to_s.empty?
        lines.pop if lines.last.to_s.strip == ":::"
        inner_source = lines.join("\n")
        inner_source += "\n" unless inner_source.empty?
        inner_tokens = Parser.parse(inner_source, @options)
        inner_html = render_sequence(inner_tokens, 0).first
        title = token.meta[:title].to_s

        if name == "details"
          summary = title.empty? ? "Details" : title
          "<details>\n<summary>#{escape(summary)}</summary>\n#{inner_html}</details>\n"
        else
          title_html = title.empty? ? "" : "<p class=\"markdown-directive-title\">#{escape(title)}</p>\n"
          "<aside class=\"markdown-directive markdown-directive-#{escape_attribute(name)}\">\n#{title_html}#{inner_html}</aside>\n"
        end
      end

      def render_cell(value)
        inline_tokens = Parser::InlineParser.new(@options).parse(value.to_s)
        render_inline_tokens(inline_tokens)
      end

      def fenced_code(token)
        language = token.info.to_s.split.first
        class_attribute = language && !language.empty? ? " class=\"language-#{escape_attribute(language)}\"" : ""
        "<pre><code#{class_attribute}>#{escape_raw(token.content)}</code></pre>\n"
      end

      def task_checkbox(checked)
        checked_attribute = checked ? " checked" : ""
        "<input type=\"checkbox\" disabled#{checked_attribute}> "
      end

      def find_close(tokens, index, close_type)
        tokens[(index + 1)..]&.index { |token| token.type == close_type }&.+(index + 1) || tokens.length
      end

      def escape(value)
        CGI.escapeHTML(decode_entities(value.to_s)).gsub("&#39;", "'")
      end

      def escape_attribute(value)
        CGI.escapeHTML(decode_entities(value.to_s)).gsub("`", "&#39;")
      end

      def escape_url_attribute(value)
        encoded = value.to_s.gsub(/\\([!\"#$%&'()*+,\-.\/:;<=>?@\[\\\]^_`{|}~])/, '\\1')
        encoded = decode_entities(encoded)
        encoded = URI::DEFAULT_PARSER.escape(encoded, /[^A-Za-z0-9\-._~;\/:?@&=+$,#%!()*']/)
        CGI.escapeHTML(encoded).gsub("`", "&#39;")
      end

      def escape_raw(value)
        CGI.escapeHTML(value.to_s).gsub("&#39;", "'")
      end

      def decode_entities(value)
        value.gsub(/&#x([0-9a-f]+);|&#([0-9]+);|&([A-Za-z][A-Za-z0-9]+);/i) do
          codepoint = if Regexp.last_match(1)
                        Integer(Regexp.last_match(1).to_s, 16)
                      elsif Regexp.last_match(2)
                        Regexp.last_match(2).to_i
                      end
          if codepoint
            begin
              invalid = codepoint.zero? || codepoint > 0x10ffff || (0xd800..0xdfff).cover?(codepoint)
              invalid ? "\uFFFD" : [codepoint].pack("U")
            rescue RangeError
              "\uFFFD"
            end
          else
            NAMED_ENTITIES.fetch(Regexp.last_match(3), Regexp.last_match(0))
          end
        end
      end
    end
  end
end
