# frozen_string_literal: true

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require_relative 'dummy/config/environment'

# Disable migration check - we handle this in the rake task
class ActiveRecord::Migration
  class << self
    def check_all_pending!
      # Disabled for gem testing
    end
  end
end

require 'rails/test_help'
require 'minitest/autorun'

# Filter backtrace for cleaner test output
Rails.backtrace_cleaner.remove_silencers!

module EventTimeline
  class TestCase < ActiveSupport::TestCase
    # Reset configuration before each test
    setup do
      EventTimeline.configuration = nil
      clear_thread_state
    end

    teardown do
      clear_thread_state
    end

    private

    def clear_thread_state
      Thread.current[:event_timeline_last_location] = nil
      Thread.current[:event_timeline_method_stack] = nil
      Thread.current[:event_timeline_event_buffer] = nil
      Thread.current[:request_id] = nil
      EventTimeline::CurrentCorrelation.reset if defined?(EventTimeline::CurrentCorrelation)
    end

    def configure_timeline(&block)
      EventTimeline.configure(&block)
    end

    def with_correlation(id)
      EventTimeline::CurrentCorrelation.id = id
      Thread.current[:request_id] = id
      yield
    ensure
      EventTimeline::CurrentCorrelation.reset
      Thread.current[:request_id] = nil
    end
  end
end

module EventTimeline
  class IntegrationTestCase < ActionDispatch::IntegrationTest
    setup do
      EventTimeline.configuration = nil
      EventTimeline::Session.delete_all
    end

    teardown do
      EventTimeline::Session.delete_all
    end
  end
end
