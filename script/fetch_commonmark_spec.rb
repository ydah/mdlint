# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

url = URI(ENV.fetch("COMMONMARK_SPEC_URL", "https://spec.commonmark.org/0.31.2/spec.json"))
destination = ARGV.fetch(0, "spec/fixtures/commonmark.json")
body = Net::HTTP.get(url)
fixtures = JSON.parse(body)
File.write(destination, JSON.pretty_generate(fixtures) + "\n")
puts "Wrote #{fixtures.length} CommonMark examples to #{destination}"
