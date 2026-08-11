# frozen_string_literal: true

require "set"
require_relative "../text_width"

module Mdlint
  module Renderer
    class MdRenderer
      BULLET_MARKERS = %w[- *].freeze
      HORIZONTAL_RULE = "_" * 70
      LINE_START_PROHIBITED = /\A[、。，．！？!?、)]|\A[）】」』〉》〕］｝…]/
      LINE_END_PROHIBITED = /[「『（【〈《〔［｛]\z/

      def initialize(options = {})
        @options = options
        @bullet_list_depth = 0
        @reference_definitions = {}
        @used_references = Set.new
      end

      def render(tokens)
        @bullet_list_depth = 0
        @reference_definitions = {}
        @used_references = Set.new
        @ordered_list_counter = 0

        # First pass: collect all reference definitions
        collect_reference_definitions(tokens)

        output = []
        render_tokens(tokens, output)

        # Append used reference definitions at the end, sorted by label
        append_reference_definitions(output)

        result = output.join
        result.gsub!(/\n{3,}/, "\n\n")

        # Apply end of line setting
        result = apply_end_of_line(result)

        result.chomp!
        result += "\n" unless result.empty?
        result
      end

      def apply_end_of_line(text)
        eol = @options[:end_of_line] || :lf
        case eol
        when :lf
          text.gsub(/\r\n/, "\n")
        when :crlf
          text.gsub(/\r?\n/, "\r\n")
        when :keep
          text
        else
          text.gsub(/\r\n/, "\n")
        end
      end

      def collect_reference_definitions(tokens)
        tokens.each do |token|
          next unless token.type == :reference_definition

          label = token.attrs[:label]
          # Only keep the first definition for each label (remove duplicates)
          @reference_definitions[label] ||= {
            url: token.attrs[:url],
            title: token.attrs[:title]
          }
        end
      end

      def append_reference_definitions(output)
        # mdformat converts reference links to inline links, so no definitions needed
        # This method is kept for potential future use or configuration options
      end

      private

      def render_tokens(tokens, output)
        i = 0
        while i < tokens.length
          token = tokens[i]
          case token.type
          when :heading_open
            i = render_heading(tokens, i, output)
          when :paragraph_open
            i = render_paragraph(tokens, i, output)
          when :bullet_list_open
            i = render_bullet_list(tokens, i, output)
          when :ordered_list_open
            i = render_ordered_list(tokens, i, output)
          when :blockquote_open
            i = render_blockquote(tokens, i, output)
          when :fence
            render_fence(token, output)
            i += 1
          when :code_block
            render_code_block(token, output)
            i += 1
          when :hr
            output << "#{HORIZONTAL_RULE}\n\n"
            i += 1
          when :html_block
            output << token.content
            output << "\n" unless token.content.end_with?("\n")
            i += 1
          when :front_matter
            output << token.content
            output << "\n" unless token.content.end_with?("\n")
            output << "\n"
            i += 1
          when :directive
            output << token.content
            output << "\n" unless token.content.end_with?("\n")
            output << "\n"
            i += 1
          when :table
            render_table(token, output)
            i += 1
          when :math_block, :footnote_definition
            output << token.content
            output << "\n" unless token.content.end_with?("\n")
            output << "\n"
            i += 1
          when :reference_definition
            # Skip - will be output at the end
            i += 1
          else
            i += 1
          end
        end
      end

      def render_heading(tokens, start_index, output)
        open_token = tokens[start_index]
        level = open_token.tag[1].to_i
        markup = "#" * level

        inline_content = ""
        i = start_index + 1
        while i < tokens.length && tokens[i].type != :heading_close
          if tokens[i].type == :inline
            inline_content = render_inline(tokens[i])
          end
          i += 1
        end

        output << "#{markup} #{inline_content}\n\n"
        i + 1
      end

      def render_paragraph(tokens, start_index, output)
        inline_content = ""
        i = start_index + 1
        while i < tokens.length && tokens[i].type != :paragraph_close
          if tokens[i].type == :inline
            inline_content = render_inline(tokens[i])
          end
          i += 1
        end

        wrapped_content = wrap_text(inline_content)
        output << "#{wrapped_content}\n\n"
        i + 1
      end

      def wrap_text(text)
        wrap_mode = @options[:wrap] || :keep

        case wrap_mode
        when :keep
          text
        when :no
          # Remove soft line breaks, join lines
          text.gsub(/\n(?!\n)/, " ")
        when Integer
          # Wrap at specified width
          wrap_at_width(text, wrap_mode)
        else
          text
        end
      end

      def wrap_at_width(text, width)
        return text if width <= 0

        lines = []
        paragraphs = text.split(/\n\n+/)

        paragraphs.each_with_index do |paragraph, idx|
          # Join lines within paragraph
          paragraph = paragraph.gsub(/\n(?!\n)/, " ")
          words = paragraph.split(/\s+/)
          current_line = ""

          words.each do |word|
            if current_line.empty?
              current_line = word
            elsif (TextWidth.measure(current_line) + 1 + TextWidth.measure(word)) <= width
              current_line += " " + word
            else
              lines.concat(split_to_width(current_line, width))
              current_line = word
            end
          end

          lines.concat(split_to_width(current_line, width)) unless current_line.empty?
          lines << "" if idx < paragraphs.length - 1
        end

        lines.join("\n")
      end

      def split_to_width(text, width)
        return [text] if TextWidth.measure(text) <= width

        chunks = []
        remaining = text
        while !remaining.empty?
          chunk = TextWidth.take(remaining, width).to_s
          break if chunk.empty?

          if remaining.length > chunk.length && chunk.match?(LINE_END_PROHIBITED)
            moved = chunk[-1].to_s
            chunk = chunk[0...-1].to_s
            remaining = moved + (remaining[chunk.length + 1..] || "")
          end

          if remaining.match?(LINE_START_PROHIBITED)
            first = remaining[0].to_s
            first_width = TextWidth.measure(first)
            if TextWidth.measure(chunk) + first_width <= width
              chunk = chunk.to_s + first
              remaining = remaining[1..] || ""
            elsif chunk.length > 1
              moved = chunk[-1].to_s
              chunk = chunk[0...-1].to_s
              remaining = moved + remaining.to_s
            end
          end

          chunks << chunk
          remaining = remaining[chunk.length..] || ""
        end
        chunks
      end

      def render_bullet_list(tokens, start_index, output)
        marker = BULLET_MARKERS[@bullet_list_depth % 2]
        @bullet_list_depth += 1
        i = start_index + 1

        while i < tokens.length && tokens[i].type != :bullet_list_close
          if tokens[i].type == :list_item_open
            i = render_list_item(tokens, i, output, "#{marker} ")
          else
            i += 1
          end
        end

        @bullet_list_depth -= 1
        output << "\n" unless output.last&.end_with?("\n\n")
        i + 1
      end

      def render_ordered_list(tokens, start_index, output)
        open_token = tokens[start_index]
        start_num = open_token.attrs[:start] || 1
        current_num = start_num
        i = start_index + 1

        while i < tokens.length && tokens[i].type != :ordered_list_close
          if tokens[i].type == :list_item_open
            if @options[:number]
              # Consecutive numbering mode
              i = render_list_item(tokens, i, output, "#{current_num}. ")
              current_num += 1
            else
              # mdformat default: all items use the same number (start number)
              i = render_list_item(tokens, i, output, "#{start_num}. ")
            end
          else
            i += 1
          end
        end

        output << "\n" unless output.last&.end_with?("\n\n")
        i + 1
      end

      def render_list_item(tokens, start_index, output, prefix)
        open_token = tokens[start_index]
        i = start_index + 1
        item_content = []

        while i < tokens.length && tokens[i].type != :list_item_close
          token = tokens[i]
          case token.type
          when :paragraph_open
            i = collect_paragraph_content(tokens, i, item_content)
          when :bullet_list_open
            nested_output = []
            i = render_bullet_list(tokens, i, nested_output)
            nested = nested_output.join.split("\n").map { |l| "   #{l}" }.join("\n")
            item_content << nested
          when :ordered_list_open
            nested_output = []
            i = render_ordered_list(tokens, i, nested_output)
            nested = nested_output.join.split("\n").map { |l| "   #{l}" }.join("\n")
            item_content << nested
          else
            i += 1
          end
        end

        content = item_content.join("\n").strip
        task_prefix = if open_token.attrs[:task]
                        checked = open_token.attrs[:checked] ? "x" : " "
                        "[#{checked}] "
                      else
                        ""
                      end
        output << "#{prefix}#{task_prefix}#{content}\n"
        i + 1
      end

      def render_table(token, output)
        rows = token.meta.fetch(:rows, [])
        return if rows.empty?

        alignments = token.meta.fetch(:alignments, [])
        if @options.fetch(:table_align, true)
          column_count = rows.map(&:length).max || 0
          widths = column_count.times.map do |index|
            [rows.map { |row| TextWidth.measure(row[index].to_s) }.max || 0, 3].max
          end
          output << "| #{render_table_row(rows.first, widths, alignments)} |\n"
          separators = widths.each_index.map { |index| table_separator(alignments[index], widths[index]) }
          output << "| #{separators.join(" | ")} |\n"
          rows.drop(1).each { |row| output << "| #{render_table_row(row, widths, alignments)} |\n" }
        else
          header = rows.first
          output << "| #{header.join(" | ")} |\n"
          separators = header.each_index.map { |index| table_separator(alignments[index], 3) }
          output << "| #{separators.join(" | ")} |\n"
          rows.drop(1).each { |row| output << "| #{row.join(" | ")} |\n" }
        end
        output << "\n"
      end

      def render_table_row(row, widths, alignments)
        widths.each_index.map do |index|
          value = row[index].to_s
          padding = widths[index] - TextWidth.measure(value)
          case alignments[index]
          when :right
            " " * padding + value
          when :center
            left = padding / 2
            " " * left + value + " " * (padding - left)
          else
            value + " " * padding
          end
        end.join(" | ")
      end

      def table_separator(alignment, width)
        width = [width, 3].max
        case alignment
        when :center
          ":#{"-" * width}:"
        when :left
          ":#{"-" * width}"
        when :right
          "#{"-" * width}:"
        else
          "-" * width
        end
      end

      def collect_paragraph_content(tokens, start_index, content_array)
        i = start_index + 1
        while i < tokens.length && tokens[i].type != :paragraph_close
          if tokens[i].type == :inline
            content_array << render_inline(tokens[i])
          end
          i += 1
        end
        i + 1
      end

      def render_blockquote(tokens, start_index, output)
        open_token = tokens[start_index]
        i = start_index + 1
        inner_output = []

        while i < tokens.length && tokens[i].type != :blockquote_close
          token = tokens[i]
          case token.type
          when :paragraph_open
            i = render_paragraph(tokens, i, inner_output)
          when :heading_open
            i = render_heading(tokens, i, inner_output)
          when :blockquote_open
            i = render_blockquote(tokens, i, inner_output)
          else
            i += 1
          end
        end

        quoted = inner_output.join.chomp.split("\n").map { |l| "> #{l}".rstrip }.join("\n")
        if open_token.attrs[:alert]
          label = open_token.attrs[:alert].upcase
          quoted = "> [!#{label}]\n#{quoted}" unless quoted.empty?
          quoted = "> [!#{label}]" if quoted.empty?
        end
        output << "#{quoted}\n\n"
        i + 1
      end

      def render_fence(token, output)
        info = token.info || ""
        content = token.content.chomp

        # Determine the minimum number of backticks needed
        backtick_count = 3
        content.scan(/`+/) do |match|
          backtick_count = [backtick_count, match.length + 1].max
        end

        marker = "`" * backtick_count

        output << "#{marker}#{info}\n"
        output << "#{content}\n"
        output << "#{marker}\n\n"
      end

      def render_code_block(token, output)
        # Convert indented code blocks to fenced code blocks (mdformat style)
        content = token.content.chomp

        # Determine the minimum number of backticks needed
        backtick_count = 3
        content.scan(/`+/) do |match|
          backtick_count = [backtick_count, match.length + 1].max
        end

        marker = "`" * backtick_count

        output << "#{marker}\n"
        output << "#{content}\n"
        output << "#{marker}\n\n"
      end

      def render_inline(token)
        return token.content if token.children.empty?

        render_inline_tokens(token.children)
      end

      def render_inline_tokens(tokens)
        output = []
        i = 0

        while i < tokens.length
          token = tokens[i]
          case token.type
          when :text
            output << token.content
          when :code_inline
            content = token.content
            # Strip unnecessary leading/trailing spaces (unless content contains backticks)
            unless content.include?("`")
              content = content.strip
            end
            # Determine minimum backticks needed
            backtick_count = 1
            content.scan(/`+/) do |match|
              backtick_count = [backtick_count, match.length + 1].max
            end
            backticks = "`" * backtick_count
            # Add space padding if content starts/ends with backtick
            if content.start_with?("`") || content.end_with?("`")
              output << "#{backticks} #{content} #{backticks}"
            else
              output << "#{backticks}#{content}#{backticks}"
            end
          when :math_inline
            output << "$#{token.content}$"
          when :footnote_ref
            output << "[^#{token.attrs[:label]}]"
          when :strong_open
            markup = token.markup.empty? ? "**" : token.markup
            close_index = find_close_token(tokens, i, :strong_close)
            inner = render_inline_tokens(tokens[(i + 1)...close_index])
            output << "#{markup}#{inner}#{markup}"
            i = close_index
          when :em_open
            markup = token.markup.empty? ? "*" : token.markup
            close_index = find_close_token(tokens, i, :em_close)
            inner = render_inline_tokens(tokens[(i + 1)...close_index])
            output << "#{markup}#{inner}#{markup}"
            i = close_index
          when :s_open
            close_index = find_close_token(tokens, i, :s_close)
            inner = render_inline_tokens(tokens[(i + 1)...close_index])
            output << "~~#{inner}~~"
            i = close_index
          when :link_open
            close_index = find_close_token(tokens, i, :link_close)
            inner = render_inline_tokens(tokens[(i + 1)...close_index])

            if token.markup == "autolink"
              href = token.attrs[:href] || ""
              output << "<#{href}>"
            elsif token.markup == "reference"
              # Reference link - resolve from definitions
              label = token.attrs[:reference_label]
              ref = @reference_definitions[label]
              if ref
                @used_references << label
                formatted_href = format_link_url(ref[:url])
                if ref[:title]
                  output << "[#{inner}](#{formatted_href} \"#{ref[:title]}\")"
                else
                  output << "[#{inner}](#{formatted_href})"
                end
              else
                # Reference not found, keep as-is
                output << "[#{inner}]"
              end
            else
              href = token.attrs[:href] || ""
              title = token.attrs[:title]
              formatted_href = format_link_url(href)
              if title
                output << "[#{inner}](#{formatted_href} \"#{title}\")"
              else
                output << "[#{inner}](#{formatted_href})"
              end
            end
            i = close_index
          when :image
            alt = token.attrs[:alt] || token.content || ""
            src = token.attrs[:src] || ""
            title = token.attrs[:title]
            if title
              output << "![#{alt}](#{src} \"#{title}\")"
            else
              output << "![#{alt}](#{src})"
            end
          when :softbreak
            output << "\n"
          when :hardbreak
            output << "\\\n"
          when :html_inline
            output << token.content
          end
          i += 1
        end

        output.join
      end

      def find_close_token(tokens, start_index, close_type)
        i = start_index + 1
        while i < tokens.length
          return i if tokens[i].type == close_type

          i += 1
        end
        tokens.length
      end

      def format_link_url(url)
        # Remove angle brackets if present and not needed
        url = url.gsub(/^<|>$/, "")
        # Add angle brackets only if URL contains spaces or parentheses
        if url.match?(/[\s()]/)
          "<#{url}>"
        else
          url
        end
      end
    end
  end
end
