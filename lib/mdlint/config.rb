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
      exclude: [],
      rules: nil,
      disable: [],
      severity: nil,
      fail_level: :warning,
      format: nil,
      dialect: :commonmark,
      preset: nil,
      plugins: [],
      check_links: false,
      check_external_links: false,
      check_code_blocks: false,
      toc: false,
      table_align: true,
      jobs: 1,
      cache: false,
      cache_path: ".mdlint_cache"
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
        when :disable, :plugins
          @options[key] = (@options[key] + Array(value)).uniq
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
      options[:wrap] = normalize_wrap(parsed[:wrap]) if parsed.key?(:wrap)
      options[:number] = parsed[:number] if parsed.key?(:number)
      options[:end_of_line] = parsed[:end_of_line].to_s.downcase.to_sym if parsed[:end_of_line]
      options[:rules] = normalize_rules(parsed[:rules]) if parsed.key?(:rules)

      if parsed[:disable]
        options[:disable] = Array(parsed[:disable]).map(&:to_s)
      end

      options[:severity] = parsed[:severity].to_sym if parsed[:severity]
      options[:fail_level] = parsed[:fail_level].to_sym if parsed[:fail_level]
      options[:format] = parsed[:format].to_s if parsed[:format]
      options[:dialect] = parsed[:dialect].to_sym if parsed[:dialect]
      options[:preset] = parsed[:preset].to_sym if parsed[:preset]
      options[:plugins] = Array(parsed[:plugins]).map(&:to_s) if parsed[:plugins]
      options[:check_links] = parsed[:check_links] if parsed.key?(:check_links)
      options[:check_external_links] = parsed[:check_external_links] if parsed.key?(:check_external_links)
      options[:check_code_blocks] = parsed[:check_code_blocks] if parsed.key?(:check_code_blocks)
      options[:toc] = parsed[:toc] if parsed.key?(:toc)
      options[:table_align] = parsed[:table_align] if parsed.key?(:table_align)
      options[:jobs] = parsed[:jobs].to_i if parsed[:jobs]
      options[:cache] = parsed[:cache] if parsed.key?(:cache)
      options[:cache_path] = parsed[:cache_path].to_s if parsed[:cache_path]

      if parsed[:exclude]
        options[:exclude] = Array(parsed[:exclude])
      end

      options
    end

    def normalize_rules(rules)
      return rules unless rules.is_a?(Hash)

      rules.each_with_object({}) do |(rule_id, setting), normalized|
        normalized[rule_id.to_s] = if setting.is_a?(Hash)
                                     normalized_setting = setting.transform_keys(&:to_sym)
                                     normalized_setting[:severity] = normalized_setting[:severity].to_sym if normalized_setting[:severity]
                                     normalized_setting
                                   else
                                     setting
                                   end
      end
    end

    def normalize_wrap(value)
      case value.to_s.downcase
      when "keep" then :keep
      when "no" then :no
      else Integer(value)
      end
    rescue ArgumentError, TypeError
      :keep
    end

    def merge_options(file_options)
      file_options.each do |key, value|
        case key
        when :exclude
          @options[:exclude] = (@options[:exclude] + value).uniq
        when :disable, :plugins
          @options[key] = (@options[key] + Array(value)).uniq
        else
          @options[key] = value
        end
      end
    end
  end
end
