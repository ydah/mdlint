# frozen_string_literal: true

require_relative "renderer/md_renderer"

module Mdlint
  module Renderer
    class << self
      def render(tokens, options = {})
        MdRenderer.new(options).render(tokens)
      end
    end
  end
end
