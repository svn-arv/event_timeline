# frozen_string_literal: true

desc 'Generate a fresh dummy Rails app for testing'
task :generate_dummy do
  dummy_path = File.expand_path('test/dummy', __dir__.sub('/tasks', ''))

  if File.exist?(dummy_path)
    puts 'Removing existing dummy app...'
    FileUtils.rm_rf(dummy_path)
  end

  puts 'Creating dummy Rails app...'
  FileUtils.mkdir_p('test')

  generate_rails_app(dummy_path)
  configure_dummy_app(dummy_path)
  create_test_files(dummy_path)
  setup_database(dummy_path)

  puts "\nDummy app created at test/dummy"
  puts "Run 'rake test' to execute tests"
end

def generate_rails_app(dummy_path)
  flags = %w[
    --skip-git
    --skip-keeps
    --skip-action-mailer
    --skip-action-mailbox
    --skip-action-text
    --skip-active-storage
    --skip-action-cable
    --skip-hotwire
    --skip-jbuilder
    --skip-test
    --skip-system-test
    --skip-bootsnap
    --skip-dev-gems
    --skip-ci
    --skip-docker
    --skip-rubocop
    --skip-brakeman
    --skip-asset-pipeline
    --skip-javascript
    --database=sqlite3
    --skip-bundle
    --quiet
  ].join(' ')

  system("rails new test/dummy #{flags}") || abort('Failed to generate Rails app')
end

def configure_dummy_app(dummy_path)
  # Add gem reference to Gemfile
  gemfile_path = File.join(dummy_path, 'Gemfile')
  gemfile_content = File.read(gemfile_path)
  gemfile_content += "\n# EventTimeline gem (local)\ngem 'event_timeline', path: '../..'\n"
  File.write(gemfile_path, gemfile_content)

  # Disable migration check in test environment
  test_env_path = File.join(dummy_path, 'config', 'environments', 'test.rb')
  test_env_content = File.read(test_env_path)
  test_env_content.sub!('Rails.application.configure do', <<~RUBY.chomp)
    Rails.application.configure do
      # Disable migration checks for gem testing
      config.active_record.migration_error = false
  RUBY
  File.write(test_env_path, test_env_content)

  # Create initializer
  initializer_dir = File.join(dummy_path, 'config', 'initializers')
  FileUtils.mkdir_p(initializer_dir)
  File.write(File.join(initializer_dir, 'event_timeline.rb'), <<~RUBY)
    # frozen_string_literal: true

    EventTimeline.configure do |config|
      config.watch 'app/controllers'
      config.watch 'app/models'
      config.watch 'app/services'
    end
  RUBY

  # Mount engine in routes
  routes_path = File.join(dummy_path, 'config', 'routes.rb')
  File.write(routes_path, <<~RUBY)
    # frozen_string_literal: true

    Rails.application.routes.draw do
      mount EventTimeline::Engine => '/event_timeline'

      get 'test', to: 'test#index'
      get 'test/error', to: 'test#error'
      get 'up', to: 'rails/health#show', as: :rails_health_check
    end
  RUBY
end

def create_test_files(dummy_path)
  create_test_controller(dummy_path)
  create_widget_model(dummy_path)
  create_calculator_service(dummy_path)
end

def create_test_controller(dummy_path)
  controllers_dir = File.join(dummy_path, 'app', 'controllers')
  File.write(File.join(controllers_dir, 'test_controller.rb'), <<~RUBY)
    # frozen_string_literal: true

    class TestController < ApplicationController
      def index
        result = process_data({ name: 'Test', value: 42 })
        render json: { status: 'ok', result: result, request_id: request.request_id }
      end

      def error
        raise StandardError, 'Test error'
      end

      private

      def process_data(data)
        validate_data(data)
        transform_data(data)
      end

      def validate_data(data)
        raise ArgumentError, 'Name required' unless data[:name]
        true
      end

      def transform_data(data)
        { processed: true, original: data }
      end
    end
  RUBY
end

def create_widget_model(dummy_path)
  models_dir = File.join(dummy_path, 'app', 'models')
  File.write(File.join(models_dir, 'widget.rb'), <<~RUBY)
    # frozen_string_literal: true

    class Widget
      attr_accessor :name, :price

      def initialize(name:, price:)
        @name = name
        @price = price
      end

      def discounted_price(percent)
        price * (1 - percent / 100.0)
      end
    end
  RUBY
end

def create_calculator_service(dummy_path)
  services_dir = File.join(dummy_path, 'app', 'services')
  FileUtils.mkdir_p(services_dir)
  File.write(File.join(services_dir, 'calculator_service.rb'), <<~RUBY)
    # frozen_string_literal: true

    class CalculatorService
      def self.add(a, b)
        a + b
      end

      def self.multiply(a, b)
        a * b
      end

      def self.process(values)
        values.map { |v| v * 2 }
      end
    end
  RUBY
end

def setup_database(dummy_path)
  Dir.chdir(dummy_path) do
    puts 'Installing dependencies...'
    system('bundle install --quiet') || abort('Bundle install failed')

    puts 'Installing migrations...'
    system('bin/rails event_timeline:install:migrations --quiet') || abort('Migration install failed')

    puts 'Setting up database...'
    system('bin/rails db:create db:migrate --quiet') || abort('Database setup failed')

    puts 'Setting up test database...'
    system('RAILS_ENV=test bin/rails db:create db:migrate --quiet') || abort('Test database setup failed')
  end
end
