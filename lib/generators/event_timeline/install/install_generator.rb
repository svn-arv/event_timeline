# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/migration'

module EventTimeline
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      desc 'Creates an EventTimeline initializer and copies migrations'

      def self.next_migration_number(dirname)
        next_migration_number = current_migration_number(dirname) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

      def copy_initializer
        template 'initializer.rb', 'config/initializers/event_timeline.rb'
      end

      def copy_migrations
        migration_template 'create_event_timeline_sessions.rb',
                           'db/migrate/create_event_timeline_sessions.rb',
                           skip: true
      end

      def show_post_install_message
        say ''
        say 'EventTimeline installed successfully!', :green
        say ''
        say 'Next steps:'
        say '  1. Run migrations: rails db:migrate'
        say '  2. Configure watched paths in config/initializers/event_timeline.rb'
        say '  3. Visit /event_timeline/sessions/:request_id to view timelines'
        say ''
      end
    end
  end
end
