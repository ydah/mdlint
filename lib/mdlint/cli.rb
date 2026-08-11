# frozen_string_literal: true

require "optparse"
require "yaml"
require_relative "../mdlint"
require_relative "config"
require_relative "cli/output_formatter"

module Mdlint
  class CLI
    FAIL_LEVELS = { info: 0, warning: 1, error: 2 }.freeze
    COMMANDS = %w[format lint fix lsp].freeze

    def initialize(argv)
      @argv = argv.dup
      @command = extract_command
      @cli_options = { exclude: [] }
    end

    def run
      parse_options
      load_config
      load_plugins
      return show_rule_list if @options[:list_rules]
      return show_rule_explanation(@options[:explain]) if @options[:explain]

      return Mdlint::Lsp::Server.new.run if @command == :lsp

      @command == :format ? process_format : process_lint
    end

    private

    def extract_command
      command = @argv.first
      return :format unless COMMANDS.include?(command)

      @argv.shift.to_sym
    end

    def load_config
      config = Config.new
      config.load
      @options = config.merge(@cli_options)
      @options[:format] ||= "text" if @command != :format
    end

    def parse_options
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: mdlint [command] [options] [paths...]"
        opts.separator ""
        opts.separator "Commands: format (default), lint, fix, lsp"
        opts.separator ""
        opts.separator "Options:"

        opts.on("-c", "--check", "Check if files are formatted, exit with error if not") { @cli_options[:check] = true }
        opts.on("-d", "--diff", "Show diff of changes") { @cli_options[:diff] = true }
        opts.on("-q", "--quiet", "Suppress output") { @cli_options[:quiet] = true }
        opts.on("-e", "--exclude PATTERN", "Exclude files matching pattern") { |pattern| @cli_options[:exclude] << pattern }
        opts.on("-w", "--wrap MODE", "Paragraph wrapping: keep, no, or INTEGER") { |mode| @cli_options[:wrap] = parse_wrap_mode(mode) }
        opts.on("--number", "Use consecutive numbering for ordered lists") { @cli_options[:number] = true }
        opts.on("--end-of-line MODE", "End of line: lf, crlf, keep") { |mode| @cli_options[:end_of_line] = mode.downcase.to_sym }
        opts.on("--fix", "Fix fixable lint violations") do
          @cli_options[:fix] = true
          @command = :lint if @command == :format
        end
        opts.on("--fix-only", "Apply fixes without reporting remaining violations") do
          @cli_options[:fix] = true
          @cli_options[:fix_only] = true
          @command = :fix
        end
        opts.on("--dry-run", "Do not write fixes to files") { @cli_options[:dry_run] = true }
        opts.on("--disable RULES", "Disable comma-separated rules") { |rules| @cli_options[:disable] = split_rules(rules) }
        opts.on("--rule RULES", "Run only comma-separated rules") { |rules| @cli_options[:rules] = split_rules(rules) }
        opts.on("--severity LEVEL", "Default severity: error, warning, or info") { |level| @cli_options[:severity] = parse_level(level) }
        opts.on("--fail-level LEVEL", "Fail at severity: error, warning, or info") { |level| @cli_options[:fail_level] = parse_level(level) }
        opts.on("--format FORMAT", "Lint output: text, json, sarif, github, checkstyle, junit") { |format| @cli_options[:format] = format }
        opts.on("--stdin-filename NAME", "Filename to use for stdin diagnostics") { |name| @cli_options[:stdin_filename] = name }
        opts.on("--dialect DIALECT", "Markdown dialect: commonmark or gfm") { |dialect| @cli_options[:dialect] = dialect.to_sym }
        opts.on("--check-links", "Check relative link and image targets") { @cli_options[:check_links] = true }
        opts.on("--lsp", "Run the Language Server Protocol server") { @command = :lsp }
        opts.on("--list-rules", "List available lint rules") { @cli_options[:list_rules] = true }
        opts.on("--explain RULE", "Explain a lint rule") { |rule| @cli_options[:explain] = rule }
        opts.on("--require PATH", "Load a custom rule file") { |path| (@cli_options[:require] ||= []) << path }
        opts.on("--auto-gen-config [PATH]", "Write a config disabling current violations") do |path|
          @cli_options[:auto_gen_config] = path || ".mdlint_todo.yml"
        end
        opts.on("-v", "--version", "Show version") do
          puts "mdlint #{Mdlint::VERSION}"
          exit 0
        end
        opts.on("-h", "--help", "Show help") do
          puts opts
          exit 0
        end
      end

      parser.parse!(@argv)
    end

    def process_format
      return process_format_stdin if @argv.empty?

      files = collect_files(@argv)
      changed_files = files.filter_map { |file| file if process_format_file(file) }

      if @options[:check]
        exit(changed_files.empty? ? 0 : 1)
      end

      unless @options[:quiet] || @options[:diff]
        puts(changed_files.empty? ? "All files are formatted correctly" : "#{changed_files.length} file(s) reformatted")
      end
      @options[:diff] && changed_files.any? ? 1 : 0
    end

    def process_format_stdin
      input = $stdin.read
      output = Mdlint.format(input, format_options)

      if @options[:check]
        exit(input == output ? 0 : 1)
      elsif @options[:diff]
        show_diff("stdin", input, output)
        exit(input == output ? 0 : 1)
      else
        print output
        0
      end
    end

    def process_format_file(file)
      original = File.read(file)
      formatted = Mdlint.format(original, format_options)
      changed = original != formatted
      return false unless changed

      if @options[:diff]
        show_diff(file, original, formatted)
      elsif @options[:check]
        puts "Would reformat: #{file}" unless @options[:quiet]
      else
        File.write(file, formatted)
        puts "Reformatted: #{file}" unless @options[:quiet]
      end
      true
    end

    def process_lint
      entries = if @argv.empty?
                  process_lint_stdin
                else
                  collect_files(@argv).flat_map { |file| process_lint_file(file) }
                end

      print lint_output(entries) unless @options[:quiet]
      return write_auto_gen_config(entries) if @options[:auto_gen_config]

      fail_for?(entries) ? exit(1) : 0
    end

    def load_plugins
      paths = Array(@options[:plugins]) + Array(@options[:require])
      paths.each do |path|
        require File.expand_path(path, Dir.pwd)
      rescue LoadError, StandardError => error
        warn "Warning: Could not load rule file #{path}: #{error.message}"
        exit 2
      end
    end

    def write_auto_gen_config(entries)
      rules = entries.to_h { |entry| [entry[:violation].rule_id, false] }
      path = @options[:auto_gen_config]
      File.write(path, YAML.dump("rules" => rules))
      puts "Wrote #{path}" unless @options[:quiet]
      0
    end

    def process_lint_stdin
      filename = @options[:stdin_filename] || "stdin"
      source = $stdin.read
      fixed_source = apply_lint_fix(filename, source, nil)
      return [] if @options[:fix_only]

      Mdlint.lint(fixed_source, lint_options(filename)).map { |violation| { filename: filename, violation: violation } }
    end

    def process_lint_file(file)
      source = File.read(file)
      fixed_source = apply_lint_fix(file, source, file)
      return [] if @options[:fix_only]

      Mdlint.lint(fixed_source, lint_options(file)).map { |violation| { filename: file, violation: violation } }
    end

    def apply_lint_fix(filename, source, path)
      return source unless fix_requested?

      fixed = Mdlint.fix(source, lint_options(filename))
      return source if fixed == source

      if path && !@options[:dry_run]
        File.write(path, fixed)
        puts "Fixed: #{filename}" unless @options[:quiet]
      elsif path.nil? && !@options[:dry_run] && !@options[:quiet]
        print fixed
      end
      fixed
    end

    def fix_requested?
      @cli_options[:fix] || @command == :fix
    end

    def lint_output(entries)
      format = @options[:format] || "text"
      OutputFormatter.new(format).render(entries)
    end

    def fail_for?(entries)
      threshold = FAIL_LEVELS.fetch(@options[:fail_level].to_sym, FAIL_LEVELS[:warning])
      entries.any? { |entry| FAIL_LEVELS.fetch(entry[:violation].severity, FAIL_LEVELS[:warning]) >= threshold }
    end

    def show_rule_list
      Mdlint::Linter::RuleRegistry.all.each do |rule|
        aliases = Array(rule.aliases)
        alias_text = aliases.empty? ? "" : " (#{aliases.join(", ")})"
        puts "#{rule.rule_id}#{alias_text}: #{rule.description}"
      end
      exit 0
    end

    def show_rule_explanation(rule_id)
      rule = Mdlint::Linter::RuleRegistry.find(rule_id)
      unless rule
        warn "Unknown rule: #{rule_id}"
        exit 2
      end

      puts rule.rule_id
      puts "Aliases: #{Array(rule.aliases).join(", ")}" unless Array(rule.aliases).empty?
      puts rule.description
      exit 0
    end

    def collect_files(paths)
      paths.flat_map do |path|
        if File.directory?(path)
          Dir.glob(File.join(path, "**", "*.md")).reject { |file| excluded?(file) }
        elsif File.file?(path)
          excluded?(path) ? [] : [path]
        else
          warn "Warning: #{path} does not exist"
          []
        end
      end.sort
    end

    def excluded?(file)
      @options[:exclude].any? { |pattern| File.fnmatch?(pattern, file, File::FNM_PATHNAME) }
    end

    def show_diff(filename, original, formatted)
      require "tempfile"

      Tempfile.create("mdlint-original") do |original_file|
        Tempfile.create("mdlint-formatted") do |formatted_file|
          original_file.write(original)
          original_file.flush
          formatted_file.write(formatted)
          formatted_file.flush
          diff_output = `diff -u "#{original_file.path}" "#{formatted_file.path}" 2>&1`
          puts diff_output.gsub(original_file.path, "#{filename} (original)")
                          .gsub(formatted_file.path, "#{filename} (formatted)") unless diff_output.empty?
        end
      end
    end

    def format_options
      {
        wrap: @options[:wrap] || :keep,
        number: @options[:number] || false,
        end_of_line: @options[:end_of_line] || :lf,
        dialect: @options[:dialect] || :commonmark
      }
    end

    def lint_options(filename = nil)
      {
        rules: @options[:rules],
        disable: @options[:disable] || [],
        severity: @options[:severity],
        dialect: @options[:dialect] || :commonmark,
        check_links: @options[:check_links],
        filename: filename
      }.compact
    end

    def split_rules(value)
      value.split(",").map(&:strip).reject(&:empty?)
    end

    def parse_wrap_mode(mode)
      case mode.downcase
      when "keep" then :keep
      when "no" then :no
      else Integer(mode)
      end
    rescue ArgumentError
      warn "Invalid wrap mode: #{mode}. Using 'keep'."
      :keep
    end

    def parse_level(level)
      value = level.downcase.to_sym
      return value if FAIL_LEVELS.key?(value)

      raise OptionParser::InvalidArgument, "invalid severity: #{level}"
    end
  end
end
