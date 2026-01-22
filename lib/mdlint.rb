# frozen_string_literal: true

require_relative "mdlint/version"
require_relative "mdlint/token"
require_relative "mdlint/parser"
require_relative "mdlint/renderer"
require_relative "mdlint/linter"

module Mdlint
  class Error < StandardError; end

  class << self
    def format(src, options = {})
      tokens = Parser.parse(src)
      Renderer.render(tokens, options)
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

    def parse(src)
      Parser.parse(src)
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
