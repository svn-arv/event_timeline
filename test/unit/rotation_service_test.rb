# frozen_string_literal: true

require 'test_helper'

module EventTimeline
  class RotationServiceTest < TestCase
    setup do
      Session.delete_all
    end

    teardown do
      Session.delete_all
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
        RotationService.cleanup_if_needed
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

      RotationService.cleanup_if_needed

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
        RotationService.cleanup_if_needed
      end
    end

    test 'enforce_correlation_limit removes oldest events for correlation' do
      configure_timeline do |config|
        config.max_events_per_correlation = 10
      end

      correlation_id = 'limited-correlation'

      # Create 15 events for this correlation
      15.times do |i|
        Session.create!(
          name: "event_#{i}",
          correlation_id: correlation_id,
          occurred_at: i.minutes.ago
        )
      end

      RotationService.enforce_correlation_limit(correlation_id)

      # Should keep 80% of max (8 events)
      remaining = Session.where(correlation_id: correlation_id).count
      assert_equal 8, remaining
    end

    test 'enforce_correlation_limit does nothing when below limit' do
      configure_timeline do |config|
        config.max_events_per_correlation = 100
      end

      correlation_id = 'under-limit'

      5.times do |i|
        Session.create!(
          name: "event_#{i}",
          correlation_id: correlation_id,
          occurred_at: Time.current
        )
      end

      assert_no_difference 'Session.count' do
        RotationService.enforce_correlation_limit(correlation_id)
      end
    end

    test 'enforce_correlation_limit only affects specified correlation' do
      configure_timeline do |config|
        config.max_events_per_correlation = 10
      end

      # Create events for two correlations
      15.times do |i|
        Session.create!(
          name: "event_#{i}",
          correlation_id: 'correlation-a',
          occurred_at: i.minutes.ago
        )
      end

      5.times do |i|
        Session.create!(
          name: "event_#{i}",
          correlation_id: 'correlation-b',
          occurred_at: Time.current
        )
      end

      RotationService.enforce_correlation_limit('correlation-a')

      # correlation-a should be reduced, correlation-b unchanged
      assert_equal 8, Session.where(correlation_id: 'correlation-a').count
      assert_equal 5, Session.where(correlation_id: 'correlation-b').count
    end

    test 'enforce_correlation_limit does nothing without configuration' do
      EventTimeline.configuration = nil

      correlation_id = 'no-config'
      5.times do |i|
        Session.create!(
          name: "event_#{i}",
          correlation_id: correlation_id,
          occurred_at: Time.current
        )
      end

      assert_no_difference 'Session.count' do
        RotationService.enforce_correlation_limit(correlation_id)
      end
    end
  end
end
