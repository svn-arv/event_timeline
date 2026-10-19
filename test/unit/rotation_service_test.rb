# frozen_string_literal: true

require 'test_helper'

module EventTimeline
  class RotationServiceTest < TestCase
    setup do
      Session.delete_all
      RotationService.reset_counters!
    end

    teardown do
      Session.delete_all
      RotationService.reset_counters!
    end

    test 'cleanup_if_needed does nothing when below threshold' do
      configure_timeline do |config|
        config.max_total_events = 100
        config.cleanup_threshold = 0.8 # 80 events triggers cleanup
      end

      # Create 50 events (below 80% threshold)
      50.times do |i|
        Session.create!(
          name: "event_#{i}",
          correlation_id: 'test-correlation',
          occurred_at: Time.current
        )
      end

      assert_no_difference 'Session.count' do
        RotationService.cleanup_if_needed(force: true)
      end
    end

    test 'cleanup_if_needed removes events when above threshold' do
      configure_timeline do |config|
        config.max_total_events = 100
        config.cleanup_threshold = 0.8
      end

      # Create 85 events (above 80% threshold)
      85.times do |i|
        Session.create!(
          name: "event_#{i}",
          correlation_id: 'test-correlation',
          occurred_at: i.minutes.ago
        )
      end

      RotationService.cleanup_if_needed(force: true)

      # Should clean down to 70% (70 events)
      assert_operator Session.count, :<=, 70
    end

    test 'cleanup_if_needed does nothing without configuration' do
      EventTimeline.configuration = nil

      5.times do |i|
        Session.create!(
          name: "event_#{i}",
          correlation_id: 'test-correlation',
          occurred_at: Time.current
        )
      end

      assert_no_difference 'Session.count' do
        RotationService.cleanup_if_needed(force: true)
      end
    end
  end
end
