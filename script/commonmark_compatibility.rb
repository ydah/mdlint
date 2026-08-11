# frozen_string_literal: true

require "json"
require_relative "../lib/mdlint"

path = ARGV.fetch(0, "spec/fixtures/commonmark_smoke.json")
strict = ARGV.include?("--strict")
fixtures = JSON.parse(File.read(path))
exact = 0
crashes = []

fixtures.each do |fixture|
  actual = Mdlint.html(fixture.fetch("markdown"))
  exact += 1 if actual == fixture.fetch("html")
rescue StandardError => error
  crashes << { example: fixture["example"], error: "#{error.class}: #{error.message}" }
end

total = fixtures.length
percentage = total.zero? ? 100.0 : exact.fdiv(total) * 100
puts format("CommonMark fixtures: %d/%d exact (%.2f%%), %d crashes", exact, total, percentage, crashes.length)
crashes.each { |crash| warn "CRASH #{crash[:example]}: #{crash[:error]}" }

exit 1 unless crashes.empty? && (!strict || exact == total)
