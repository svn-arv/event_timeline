# frozen_string_literal: true

require_relative 'lib/timeline/version'

Gem::Specification.new do |spec|
  spec.name        = 'timeline'
  spec.version     = Timeline::VERSION
  spec.authors     = ['svn-arv']
  spec.email       = ['svn-arv@users.noreply.github.com']
  spec.summary     = 'Debug Rails apps by replaying method calls from any request'
  spec.description = 'Timeline tracks method calls in your Rails app so you can replay and debug what happened during any request. Perfect for understanding production issues and unfamiliar codebases.'
  spec.license     = 'MIT'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'rails', '>= 7.0'
end
