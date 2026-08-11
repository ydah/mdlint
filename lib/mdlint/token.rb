# frozen_string_literal: true

module Mdlint
  class Token
    attr_accessor :type, :tag, :nesting, :level, :content, :markup, :info, :meta, :map, :children, :attrs

    def initialize(type:, **kwargs)
      @type = type
      @tag = kwargs[:tag]
      @nesting = kwargs[:nesting] || 0
      @level = kwargs[:level] || 0
      @content = kwargs[:content] || ""
      @markup = kwargs[:markup] || ""
      @info = kwargs[:info] || ""
      @meta = kwargs[:meta] || {}
      @map = kwargs[:map]
      @children = kwargs[:children] || []
      @attrs = kwargs[:attrs] || {}
    end

    def opening?
      @nesting == 1
    end

    def closing?
      @nesting == -1
    end

    def self_closing?
      @nesting.zero?
    end

    def block?
      BLOCK_TYPES.include?(@type)
    end

    def inline?
      INLINE_TYPES.include?(@type)
    end

    BLOCK_TYPES = %i[
      document
      heading_open heading_close
      paragraph_open paragraph_close
      bullet_list_open bullet_list_close
      ordered_list_open ordered_list_close
      list_item_open list_item_close
      blockquote_open blockquote_close
      code_block fence
      hr html_block front_matter table directive math_block footnote_definition
      inline
    ].freeze

    INLINE_TYPES = %i[
      text
      strong_open strong_close
      em_open em_close
      s_open s_close
      math_inline footnote_ref
      code_inline
      link_open link_close
      image
      softbreak hardbreak
      html_inline
    ].freeze
  end
end
