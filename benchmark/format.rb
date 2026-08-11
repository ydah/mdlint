# frozen_string_literal: true

require_relative "../lib/mdlint"

path = ARGV.first
source = path && File.file?(path) ? File.read(path) : <<~MARKDOWN
  # Benchmark document

  This is a representative paragraph with **strong text**, `inline code`, and a [link](https://example.com).

  - one
  - two

  ```ruby
  puts "hello"
  ```
MARKDOWN

iterations = Integer(ENV.fetch("ITERATIONS", "100"))
measure = lambda do |label, &block|
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  iterations.times(&block)
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  puts format("%-16s %.6fs (%.2f ops/s)", label, elapsed, iterations / elapsed)
end

measure.call("format x#{iterations}") { Mdlint.format(source) }
measure.call("html x#{iterations}") { Mdlint.html(source) }
measure.call("lint x#{iterations}") { Mdlint.lint(source) }
