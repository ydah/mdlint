# frozen_string_literal: true

module Mdlint
  module Toc
    START_MARKERS = ["<!-- toc -->", "<!-- toc:start -->"].freeze
    END_MARKERS = ["<!-- toc -->", "<!-- toc:end -->"].freeze

    module_function

    def update(source, options = {})
      eol = source.include?("\r\n") ? "\r\n" : "\n"
      normalized_source = source.gsub("\r\n", "\n")
      lines = normalized_source.split("\n", -1)
      heading_tokens = Parser.parse(normalized_source, options)
      entries = table_of_contents(heading_tokens)
      replacement = entries.join("\n")
      marker_pairs(lines).reverse_each do |start_index, end_index|
        lines[(start_index + 1)...end_index] = replacement.empty? ? [] : replacement.lines(chomp: true)
      end
      lines.join(eol)
    end

    def table_of_contents(tokens)
      counts = Hash.new(0)
      tokens.each_with_index.filter_map do |token, index|
        next unless token.type == :heading_open

        inline = tokens[(index + 1)..]&.find { |candidate| candidate.type == :inline }
        title = inline&.content.to_s.strip
        slug = slugify(title, counts)
        next if title.empty? || slug.empty?

        level = token.tag.to_s.delete_prefix("h").to_i
        "#{"  " * [level - 1, 0].max}- [#{title}](##{slug})"
      end
    end

    def marker_pairs(lines)
      pairs = []
      index = 0
      while index < lines.length
        marker = lines[index].strip.downcase
        if marker == "<!-- toc:start -->"
          ending = lines[(index + 1)..]&.index { |line| line.strip.downcase == "<!-- toc:end -->" }
          if ending
            pairs << [index, index + ending + 1]
            index += ending + 1
          end
        elsif marker == "<!-- toc -->"
          ending = lines[(index + 1)..]&.index { |line| line.strip.downcase == "<!-- toc -->" }
          if ending
            pairs << [index, index + ending + 1]
            index += ending + 1
          end
        end
        index += 1
      end
      pairs
    end

    def slugify(value, counts)
      base = value.gsub(/[`*_~\[\]()<>]/, "")
                   .downcase
                   .gsub(/[^\p{Alnum}\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}\s-]/, "")
                   .strip
                   .gsub(/\s+/, "-")
      suffix = counts[base]
      counts[base] += 1
      suffix.zero? ? base : "#{base}-#{suffix}"
    end
  end

  class << self
    def update_toc(source, options = {})
      Toc.update(source, options)
    end
  end
end
