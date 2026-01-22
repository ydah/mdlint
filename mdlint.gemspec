# frozen_string_literal: true

require_relative "lib/mdlint/version"

Gem::Specification.new do |spec|
  spec.name = "mdlint"
  spec.version = Mdlint::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "A Pure Ruby Markdown linter and formatter"
  spec.description = "Mdlint is a Pure Ruby Markdown linter and formatter with no external dependencies. It provides configurable lint rules and automatic formatting for consistent Markdown files."
  spec.homepage = "https://github.com/ydah/mdlint"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ydah/mdlint"
  spec.metadata["changelog_uri"] = "https://github.com/ydah/mdlint/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
