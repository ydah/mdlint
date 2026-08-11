# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

namespace :commonmark do
  task :fetch do
    sh "ruby script/fetch_commonmark_spec.rb"
  end

  task :compatibility do
    sh "ruby script/fetch_commonmark_spec.rb spec/fixtures/commonmark.json"
    sh "ruby script/commonmark_compatibility.rb spec/fixtures/commonmark.json"
  end
end

task default: :spec
