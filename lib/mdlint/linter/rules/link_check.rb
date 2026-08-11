# frozen_string_literal: true

module Mdlint
  module Linter
    module Rules
      class LinkCheck < Rule
        self.rule_id = "MD052"
        self.aliases = ["link-check"]
        self.description = "Relative links should point to existing files"

        def check(tokens, _source)
          return @violations unless @options[:check_links]

          tokens.each do |token|
            next unless token.type == :inline

            token.children.each do |child|
              next unless child.type == :link_open || child.type == :image

              target = child.attrs[:href] || child.attrs[:src]
              check_target(target, token)
            end
          end
          @violations
        end

        private

        def check_target(target, token)
          return if target.nil? || target.empty? || target.start_with?("#")
          return if target.match?(%r{\A(?:https?|ftp|mailto):}i)

          path = target.split("#", 2).first
          base = @options[:filename] && File.dirname(@options[:filename])
          return unless base
          return if File.file?(File.expand_path(path, base))

          add_violation(
            message: "Link target does not exist: #{path}",
            line: (token.map&.first || 0) + 1,
            fixable: false
          )
        end
      end
    end
  end
end
