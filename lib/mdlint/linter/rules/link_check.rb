# frozen_string_literal: true

require "net/http"
require "timeout"
require "uri"

module Mdlint
  module Linter
    module Rules
      class LinkCheck < Rule
        self.rule_id = "MD052"
        self.aliases = ["link-check"]
        self.description = "Relative links should point to existing files"

        def check(tokens, source)
          return @violations unless @options[:check_links] || @options[:check_external_links]

          @headings = heading_slugs(tokens)

          tokens.each do |token|
            next unless token.type == :inline

            token.children.each do |child|
              next unless child.type == :link_open || child.type == :image

              target = child.attrs[:href] || child.attrs[:src]
              check_target(target, token, child.type == :image, source)
            end
          end
          @violations
        end

        private

        def check_target(target, token, image, source)
          return if target.nil? || target.empty?

          if target.match?(%r{\Ahttps?://}i)
            check_external_target(target, token) if @options[:check_external_links]
            return
          end
          return if target.match?(%r{\A(?:ftp|mailto):}i)

          path, fragment = target.split("#", 2)
          base = @options[:filename] && File.dirname(@options[:filename])
          return unless base || path.empty?

          if path.empty?
            check_fragment(fragment, token, image, @headings)
            return
          end

          resolved_path = File.expand_path(path, base)
          unless File.file?(resolved_path)
            add_missing_target(path, token)
            return
          end

          return if image || fragment.nil? || fragment.empty?
          return if non_markdown_file?(resolved_path)

          target_headings = begin
            heading_slugs(Parser.parse(File.read(resolved_path), @options))
          rescue StandardError
            []
          end
          check_fragment(fragment, token, image, target_headings)
        end

        def check_fragment(fragment, token, image, headings)
          return if image || fragment.nil? || fragment.empty?
          decoded = URI::DEFAULT_PARSER.unescape(fragment).downcase
          return if headings.include?(decoded)

          add_violation(
            message: "Link anchor does not exist: ##{fragment}",
            line: (token.map&.first || 0) + 1,
            fixable: false
          )
        end

        def add_missing_target(path, token)
          add_violation(
            message: "Link target does not exist: #{path}",
            line: (token.map&.first || 0) + 1,
            fixable: false
          )
        end

        def check_external_target(target, token)
          uri = URI.parse(target)
          response = Net::HTTP.start(
            uri.host,
            uri.port,
            use_ssl: uri.scheme == "https",
            open_timeout: 3,
            read_timeout: 3
          ) do |http|
            result = http.head(uri.request_uri)
            result.is_a?(Net::HTTPMethodNotAllowed) ? http.get(uri.request_uri) : result
          end
          return if response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection)

          add_violation(
            message: "External link returned HTTP #{response.code}: #{target}",
            line: (token.map&.first || 0) + 1,
            fixable: false
          )
        rescue URI::InvalidURIError, SocketError, SystemCallError, Timeout::Error, IOError => error
          add_violation(
            message: "External link could not be reached: #{target} (#{error.class})",
            line: (token.map&.first || 0) + 1,
            fixable: false
          )
        end

        def non_markdown_file?(path)
          !%w[.md .markdown .mdown .mkdn].include?(File.extname(path).downcase)
        end

        def heading_slugs(tokens)
          counts = Hash.new(0)
          slugs = []
          tokens.each_with_index do |token, index|
            next unless token.type == :heading_open

            inline = tokens[(index + 1)..]&.find { |candidate| candidate.type == :inline }
            base = slugify(inline&.content.to_s)
            next if base.empty?

            suffix = counts[base]
            counts[base] += 1
            slugs << (suffix.zero? ? base : "#{base}-#{suffix}")
          end
          slugs
        end

        def slugify(value)
          value = value.gsub(/[`*_~\[\]()<>]/, "")
          value.downcase.gsub(/[^\p{Alnum}\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}\s-]/, "")
               .strip.gsub(/\s+/, "-")
        end
      end
    end
  end
end
