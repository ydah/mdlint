# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"

module Mdlint
  class CacheStore
    def initialize(path)
      @path = path
      @mutex = Mutex.new
      @data = load_data
      @dirty = false
    end

    def key(source, options)
      Digest::SHA256.hexdigest(JSON.generate([source, canonicalize(options)]))
    end

    def fetch(key)
      @mutex.synchronize do
        values = @data[key]
        values&.map { |value| Linter::Violation.new(**symbolize(value)) }
      end
    end

    def store(key, violations)
      @mutex.synchronize do
        @data[key] = violations.map(&:to_h)
        @dirty = true
      end
    end

    def save
      @mutex.synchronize do
        return unless @dirty

        parent = File.dirname(@path)
        FileUtils.mkdir_p(parent) unless parent == "."
        File.write(@path, JSON.pretty_generate(@data) + "\n")
        @dirty = false
      end
    end

    private

    def load_data
      return {} unless File.file?(@path)

      JSON.parse(File.read(@path))
    rescue JSON::ParserError, SystemCallError
      {}
    end

    def canonicalize(value)
      case value
      when Hash
        value.keys.map(&:to_s).sort.to_h do |key|
          original_key = value.keys.find { |candidate| candidate.to_s == key }
          [key, canonicalize(value[original_key])]
        end
      when Array
        value.map { |item| canonicalize(item) }
      when Symbol
        value.to_s
      else
        value
      end
    end

    def symbolize(value)
      value.each_with_object({}) { |(key, item), result| result[key.to_sym] = item }
    end
  end
end
