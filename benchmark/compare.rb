# frozen_string_literal: true

require_relative "../lib/mdlint"

path = ARGV.first
source = path && File.file?(path) ? File.read(path) : <<~MARKDOWN
  # Benchmark document

  A paragraph with **strong text**, `inline code`, and a [link](https://example.com).

  - one
  - two

  ```ruby
  puts "hello"
  ```
MARKDOWN
iterations = Integer(ENV.fetch("ITERATIONS", "100"))

adapters = { "mdlint" => -> { Mdlint.html(source) } }

begin
  require "kramdown"
  adapters["kramdown"] = -> { Kramdown::Document.new(source).to_html }
rescue LoadError
  warn "kramdown: unavailable (install it to include this adapter)"
end

begin
  require "commonmarker"
  adapters["commonmarker"] = lambda do
    if Commonmarker.respond_to?(:to_html)
      Commonmarker.to_html(source)
    elsif Commonmarker.respond_to?(:render_doc)
      Commonmarker.render_doc(source).to_html
    else
      raise "unsupported commonmarker API"
    end
  end
rescue LoadError
  warn "commonmarker: unavailable (install it to include this adapter)"
end

adapters.each do |name, formatter|
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  iterations.times { formatter.call }
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  puts format("%-14s %.6fs (%.2f ops/s)", name, elapsed, iterations / elapsed)
end
