# frozen_string_literal: true

require "yaml"

module Mdlint
  class Config
    CONFIG_FILES = %w[
      .mdlint.yml
      .mdlint.yaml
      mdlint.yml
      mdlint.yaml
    ].freeze

    DEFAULT_OPTIONS = {
      check: false,
      diff: false,
      quiet: false,
      exclude: []
    }.freeze

    attr_reader :options

    def initialize(base_path = Dir.pwd)
      @base_path = base_path
      @options = DEFAULT_OPTIONS.dup
    end

    def load
      config_file = find_config_file
      return @options unless config_file

      file_options = load_config_file(config_file)
      merge_options(file_options)
      @options
    end

    def merge(cli_options)
      cli_options.each do |key, value|
        case key
        when :exclude
          @options[:exclude] = (@options[:exclude] + value).uniq
        else
          @options[key] = value unless value.nil?
        end
      end
      @options
    end

    private

    def find_config_file
      current = @base_path

      loop do
        CONFIG_FILES.each do |name|
          path = File.join(current, name)
          return path if File.exist?(path)
        end

        parent = File.dirname(current)
        break if parent == current

        current = parent
      end

      nil
    end

    def load_config_file(path)
      content = File.read(path)
      parsed = YAML.safe_load(content, symbolize_names: true) || {}
      normalize_options(parsed)
    rescue Psych::SyntaxError => e
      warn "Warning: Invalid YAML in #{path}: #{e.message}"
      {}
    end

    def normalize_options(parsed)
      options = {}

      options[:check] = parsed[:check] if parsed.key?(:check)
      options[:diff] = parsed[:diff] if parsed.key?(:diff)
      options[:quiet] = parsed[:quiet] if parsed.key?(:quiet)

      if parsed[:exclude]
        options[:exclude] = Array(parsed[:exclude])
      end

      options
    end

    def merge_options(file_options)
      file_options.each do |key, value|
        case key
        when :exclude
          @options[:exclude] = (@options[:exclude] + value).uniq
        else
          @options[key] = value
        end
      end
    end
  end
end
