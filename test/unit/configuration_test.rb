# frozen_string_literal: true

require 'test_helper'

module EventTimeline
  class ConfigurationTest < TestCase
    test 'has default values' do
      config = Configuration.new

      assert_equal [], config.watched_paths
      assert_equal 500, config.max_events_per_correlation
      assert_equal 10_000, config.max_total_events
      assert_equal 0.8, config.cleanup_threshold
      assert_equal 1.month, config.max_event_age
    end

    test 'has default filtered attributes' do
      config = Configuration.new

      assert_includes config.filtered_attributes, 'password'
      assert_includes config.filtered_attributes, 'token'
      assert_includes config.filtered_attributes, 'secret'
      assert_includes config.filtered_attributes, 'credit_card'
    end

    test 'watch adds paths' do
      configure_timeline do |config|
        config.watch 'app/services'
        config.watch 'app/models'
      end

      assert_equal 2, EventTimeline.configuration.watched_paths.size
    end

    test 'watched? matches files in watched paths' do
      configure_timeline do |config|
        config.watch 'app/services'
      end

      assert EventTimeline.configuration.watched?("#{Rails.root}/app/services/foo.rb")
      refute EventTimeline.configuration.watched?("#{Rails.root}/app/controllers/foo.rb")
    end

    test 'watched? returns false when no paths configured' do
      config = Configuration.new

      refute config.watched?('/some/path/file.rb')
    end

    test 'add_filtered_attributes adds new attributes' do
      configure_timeline do |config|
        config.add_filtered_attributes :bank_account, :routing_number
      end

      assert_includes EventTimeline.configuration.filtered_attributes, 'bank_account'
      assert_includes EventTimeline.configuration.filtered_attributes, 'routing_number'
    end

    test 'remove_filtered_attributes removes attributes' do
      configure_timeline do |config|
        config.remove_filtered_attributes :password
      end

      refute_includes EventTimeline.configuration.filtered_attributes, 'password'
    end

    test 'should_filter? returns true for sensitive keys' do
      configure_timeline do |config|
        config.watch 'app/services'
      end

      assert EventTimeline.configuration.should_filter?(:password, 'secret', {})
      assert EventTimeline.configuration.should_filter?(:api_token, 'abc123', {})
      assert EventTimeline.configuration.should_filter?(:user_password, 'secret', {})
    end

    test 'should_filter? returns false for non-sensitive keys' do
      configure_timeline do |config|
        config.watch 'app/services'
      end

      refute EventTimeline.configuration.should_filter?(:name, 'John', {})
      refute EventTimeline.configuration.should_filter?(:email, 'john@example.com', {})
    end

    test 'custom pii filter takes precedence' do
      configure_timeline do |config|
        config.filter_pii do |key, _value, _context|
          key.to_s.include?('custom_sensitive') ? true : nil
        end
      end

      assert EventTimeline.configuration.should_filter?(:custom_sensitive_field, 'data', {})
    end

    test 'custom pii filter can explicitly allow' do
      configure_timeline do |config|
        config.filter_pii do |key, _value, _context|
          key == :password_hint ? false : nil
        end
      end

      # password_hint contains 'password' but custom filter allows it
      refute EventTimeline.configuration.should_filter?(:password_hint, 'hint', {})
    end

    test 'narrator proc can be set' do
      configure_timeline do |config|
        config.narrator do |event|
          "[CUSTOM] #{event.name}"
        end
      end

      assert_not_nil EventTimeline.configuration.narrator_proc
    end

    test 'max_events_per_correlation can be configured' do
      configure_timeline do |config|
        config.max_events_per_correlation = 1000
      end

      assert_equal 1000, EventTimeline.configuration.max_events_per_correlation
    end

    test 'max_total_events can be configured' do
      configure_timeline do |config|
        config.max_total_events = 50_000
      end

      assert_equal 50_000, EventTimeline.configuration.max_total_events
    end

    test 'max_event_age can be configured' do
      configure_timeline do |config|
        config.max_event_age = 2.weeks
      end

      assert_equal 2.weeks, EventTimeline.configuration.max_event_age
    end
  end
end
