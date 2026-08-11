# frozen_string_literal: true

require_relative "mdlint/version"
require_relative "mdlint/dialect"
require_relative "mdlint/text_width"
require_relative "mdlint/parallel_runner"
require_relative "mdlint/cache_store"
require_relative "mdlint/token"
require_relative "mdlint/parser"
require_relative "mdlint/renderer"
require_relative "mdlint/linter"
require_relative "mdlint/renderer/html_renderer"
require_relative "mdlint/lsp"
require_relative "mdlint/toc"

module Mdlint
  class Error < StandardError; end

  class << self
    def format(src, options = {})
      tokens = Parser.parse(src, options)
      formatted = Renderer.render(tokens, options)
      options[:toc] ? Toc.update(formatted, options) : formatted
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
      lint(src, options.merge(filename: path))
    end
  end
end

require_relative "mdlint/plugin"

require_relative "mdlint/plugin"
