#!/usr/bin/env rake

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new

task :default => :spec

desc 'Run guard'
task :guard do
  sh %{ bundle exec guard --notify false}
end
