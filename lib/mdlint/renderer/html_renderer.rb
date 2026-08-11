# frozen_string_literal: true

require "cgi"

module Mdlint
  module Renderer
    class HtmlRenderer
      def initialize(options = {})
        @options = options
      end

      def render(tokens)
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
            output << "<blockquote>\n#{content}</blockquote>\n"
          when :fence
            output << fenced_code(token)
            index += 1
          when :code_block
            output << "<pre><code>#{escape(token.content)}</code></pre>\n"
            index += 1
          when :math_block
            output << "<div class=\"math-block\">#{escape(token.content)}</div>\n"
            index += 1
          when :footnote_definition
            label = escape_attribute(token.attrs[:label])
            content = escape(token.attrs[:content])
            output << "<div class=\"footnote\" id=\"fn-#{label}\"><sup>#{label}</sup> #{content}</div>\n"
            index += 1
          when :hr
            output << "<hr>\n"
            index += 1
          when :html_block
            output << token.content
            output << "\n" unless token.content.end_with?("\n")
            index += 1
          when :table
            output << render_table(token)
            index += 1
          when :front_matter, :directive, :reference_definition
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
            output << "<code>#{escape(token.content.strip)}</code>"
          when :math_inline
            output << "<span class=\"math-inline\">#{escape(token.content)}</span>"
          when :footnote_ref
            label = escape_attribute(token.attrs[:label])
            output << "<sup><a href=\"#fn-#{label}\">#{label}</a></sup>"
          when :link_open
            close_index = find_close(tokens, index, :link_close)
            href = escape_attribute(token.attrs[:href].to_s)
            output << "<a href=\"#{href}\">#{render_inline_tokens(tokens[(index + 1)...close_index])}</a>"
            index = close_index
          when :image
            attrs = "src=\"#{escape_attribute(token.attrs[:src])}\" alt=\"#{escape_attribute(token.attrs[:alt] || token.content)}\""
            attrs += " title=\"#{escape_attribute(token.attrs[:title])}\"" if token.attrs[:title]
            output << "<img #{attrs}>"
          when :softbreak
            output << "\n"
          when :hardbreak
            output << "<br>\n"
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

      def render_cell(value)
        inline_tokens = Parser::InlineParser.new(@options).parse(value.to_s)
        render_inline_tokens(inline_tokens)
      end

      def fenced_code(token)
        language = token.info.to_s.split.first
        class_attribute = language && !language.empty? ? " class=\"language-#{escape_attribute(language)}\"" : ""
        "<pre><code#{class_attribute}>#{escape(token.content)}</code></pre>\n"
      end

      def task_checkbox(checked)
        checked_attribute = checked ? " checked" : ""
        "<input type=\"checkbox\" disabled#{checked_attribute}> "
      end

      def find_close(tokens, index, close_type)
        tokens[(index + 1)..]&.index { |token| token.type == close_type }&.+(index + 1) || tokens.length
      end

      def escape(value)
        CGI.escapeHTML(value.to_s)
      end

      def escape_attribute(value)
        escape(value).gsub("`", "&#39;")
      end
    end
  end
end
