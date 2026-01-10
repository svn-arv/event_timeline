# frozen_string_literal: true

require_relative 'lib/event_timeline/version'

Gem::Specification.new do |spec|
  spec.name        = 'event_timeline'
  spec.version     = EventTimeline::VERSION
  spec.authors     = ['svn-arv']
  spec.email       = ['eventtimelinerails@gmail.com']
  spec.summary     = 'Debug Rails apps by replaying method calls from any request'
  spec.description = 'EventTimeline tracks method calls in your Rails app so you can replay and debug what happened during any request. Perfect for understanding production issues and unfamiliar codebases.'
  spec.license     = 'MIT'
  spec.homepage    = 'https://github.com/svn-arv/event_timeline'
  spec.required_ruby_version = '>= 3.0'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md'] -
      Dir['lib/generators/**/*.rb~'] # Exclude backup files
  end

  spec.add_dependency 'rails', '>= 7.0'

  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'sqlite3', '>= 2.0'
end
