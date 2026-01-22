# frozen_string_literal: true

require "optparse"
require "pathname"
require_relative "config"

module Mdlint
  class CLI
    def initialize(argv)
      @argv = argv.dup
      @cli_options = { exclude: [] }
    end

    def run
      parse_options
      load_config
      paths = @argv

      if paths.empty?
        process_stdin
      else
        process_paths(paths)
      end
    end

    private

    def load_config
      config = Config.new
      config.load
      @options = config.merge(@cli_options)
    end

    def parse_options
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: mdlint [options] [paths...]"
        opts.separator ""
        opts.separator "Options:"

        opts.on("-c", "--check", "Check if files are formatted, exit with error if not") do
          @cli_options[:check] = true
        end

        opts.on("-d", "--diff", "Show diff of changes") do
          @cli_options[:diff] = true
        end

        opts.on("-q", "--quiet", "Suppress output") do
          @cli_options[:quiet] = true
        end

        opts.on("-e", "--exclude PATTERN", "Exclude files matching pattern") do |pattern|
          @cli_options[:exclude] << pattern
        end

        opts.on("-w", "--wrap MODE", "Paragraph wrapping mode: keep (default), no, or INTEGER") do |mode|
          @cli_options[:wrap] = parse_wrap_mode(mode)
        end

        opts.on("--number", "Use consecutive numbering for ordered lists") do
          @cli_options[:number] = true
        end

        opts.on("--end-of-line MODE", "End of line: lf (default), crlf, keep") do |mode|
          @cli_options[:end_of_line] = mode.downcase.to_sym
        end

        opts.on("-v", "--version", "Show version") do
          puts "mdlint #{Mdlint::VERSION}"
          exit 0
        end

        opts.on("-h", "--help", "Show this help") do
          puts opts
          exit 0
        end
      end

      parser.parse!(@argv)
    end

    def process_stdin
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

    def process_paths(paths)
      files = collect_files(paths)
      changed_files = []

      files.each do |file|
        result = process_file(file)
        changed_files << file if result
      end

      if @options[:check]
        exit(changed_files.empty? ? 0 : 1)
      end

      unless @options[:quiet]
        if changed_files.any?
          puts "#{changed_files.length} file(s) reformatted" unless @options[:diff]
        else
          puts "All files are formatted correctly" unless @options[:diff]
        end
      end

      changed_files.empty? ? 0 : 1
    end

    def collect_files(paths)
      files = []

      paths.each do |path|
        if File.directory?(path)
          Dir.glob(File.join(path, "**", "*.md")).each do |file|
            files << file unless excluded?(file)
          end
        elsif File.file?(path)
          files << path unless excluded?(path)
        else
          warn "Warning: #{path} does not exist"
        end
      end

      files.sort
    end

    def excluded?(file)
      @options[:exclude].any? do |pattern|
        File.fnmatch?(pattern, file, File::FNM_PATHNAME)
      end
    end

    def process_file(file)
      original = File.read(file)
      formatted = Mdlint.format(original, format_options)
      changed = original != formatted

      if changed
        if @options[:diff]
          show_diff(file, original, formatted)
        elsif !@options[:check]
          File.write(file, formatted)
          puts "Reformatted: #{file}" unless @options[:quiet]
        elsif !@options[:quiet]
          puts "Would reformat: #{file}"
        end
      end

      changed
    end

    def show_diff(filename, original, formatted)
      require "tempfile"

      Tempfile.create("mdlint-original") do |orig_file|
        Tempfile.create("mdlint-formatted") do |fmt_file|
          orig_file.write(original)
          orig_file.flush
          fmt_file.write(formatted)
          fmt_file.flush

          diff_output = `diff -u "#{orig_file.path}" "#{fmt_file.path}" 2>&1`
          unless diff_output.empty?
            diff_output = diff_output.gsub(orig_file.path, "#{filename} (original)")
                                     .gsub(fmt_file.path, "#{filename} (formatted)")
            puts diff_output
          end
        end
      end
    end

    def parse_wrap_mode(mode)
      case mode.downcase
      when "keep"
        :keep
      when "no"
        :no
      else
        Integer(mode)
      end
    rescue ArgumentError
      warn "Invalid wrap mode: #{mode}. Using 'keep'."
      :keep
    end

    def format_options
      {
        wrap: @options[:wrap] || :keep,
        number: @options[:number] || false,
        end_of_line: @options[:end_of_line] || :lf
      }
    end
  end
end
