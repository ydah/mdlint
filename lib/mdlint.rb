# frozen_string_literal: true

require_relative "mdlint/version"
require_relative "mdlint/dialect"
require_relative "mdlint/token"
require_relative "mdlint/parser"
require_relative "mdlint/renderer"
require_relative "mdlint/linter"
require_relative "mdlint/renderer/html_renderer"

module Mdlint
  class Error < StandardError; end

  class << self
    def format(src, options = {})
      tokens = Parser.parse(src, options)
      Renderer.render(tokens, options)
    end

    def html(src, options = {})
      Renderer.render_html(Parser.parse(src, options), options)
    end

    def format_file(path, options = {})
      src = File.read(path)
      formatted = format(src, options)

      if options[:check]
        src != formatted
      else
        File.write(path, formatted) unless options[:diff]
        formatted
      end
    end

    def parse(src, options = {})
      Parser.parse(src, options)
    end

    def fix(src, options = {})
      Linter.fix(src, options)
    end

    def lint(src, options = {})
      Linter.check(src, options)
    end

    def lint_file(path, options = {})
      src = File.read(path)
      lint(src, options)
    end
  end
end
