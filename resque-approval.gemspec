# -*- encoding: utf-8 -*-
require File.expand_path('../lib/resque-approval/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name          = 'resque-approval'
  gem.version       = Resque::Plugins::Approval::VERSION
  gem.date          = Time.now.strftime('%Y-%m-%d')
  gem.description   = %q{A Resque plugin allowing jobs to be sent to a temporary
                         queue to await approval.  Once the job is approved, it
                         is placed on its normal queue.}
  gem.summary       = %q{A Resque plugin allowing jobs to be sent to a temporary
                         queue to await approval.}
  gem.homepage      = 'https://github.com/eclubb/resque-approval'
  gem.authors       = ['Earle Clubb']
  gem.email         = ['eclubb@valcom.com']

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_runtime_dependency 'resque'

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'guard'
  gem.add_development_dependency 'guard-rspec'
  gem.add_development_dependency 'resque-scheduler'
end
