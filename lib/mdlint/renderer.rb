# frozen_string_literal: true

require_relative "renderer/md_renderer"
require_relative "renderer/html_renderer"

module Mdlint
  module Renderer
    class << self
      def render(tokens, options = {})
        MdRenderer.new(options).render(tokens)
      end

      def render_html(tokens, options = {})
        HtmlRenderer.new(options).render(tokens)
      end
    end
  end
end
