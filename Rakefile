# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

namespace :commonmark do
  task :fetch do
    sh "ruby script/fetch_commonmark_spec.rb"
  end
end

task default: :spec
