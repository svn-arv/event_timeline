# frozen_string_literal: true

require 'test_helper'

module EventTimeline
  class CallTrackerTest < TestCase
    test 'thread state is isolated per thread' do
      configure_timeline do |config|
        config.watch Rails.root.join('app').to_s
      end

      Thread.current[:event_timeline_event_buffer] = [{ name: 'thread1' }]

      thread2_buffer = nil
      Thread.new do
        thread2_buffer = Thread.current[:event_timeline_event_buffer]
      end.join

      assert_nil thread2_buffer
      assert_equal [{ name: 'thread1' }], Thread.current[:event_timeline_event_buffer]
    end

    test 'cleanup_thread_state clears all thread data' do
      correlation_id = 'test-123'

      Thread.current[:event_timeline_method_stack] = { correlation_id => [{ event_id: '1' }] }
      Thread.current[:event_timeline_event_buffer] = [{ name: 'event' }]

      CallTracker.cleanup_thread_state(correlation_id)

      assert_empty Thread.current[:event_timeline_method_stack]
      assert_empty Thread.current[:event_timeline_event_buffer]
    end

    test 'flush_events inserts buffered events' do
      configure_timeline do |config|
        config.watch Rails.root.join('app').to_s
      end

      correlation_id = 'flush-test-123'
      Thread.current[:event_timeline_event_buffer] = [
        {
          name: 'TestClass#method1',
          severity: 'info',
          category: 'method_call',
          payload: { class: 'TestClass', method: 'method1' },
          correlation_id: correlation_id,
          occurred_at: Time.current
        },
        {
          name: 'TestClass#method2',
          severity: 'info',
          category: 'method_call',
          payload: { class: 'TestClass', method: 'method2' },
          correlation_id: correlation_id,
          occurred_at: Time.current
        }
      ]

      assert_difference 'Session.count', 2 do
        CallTracker.flush_events(correlation_id)
      end

      events = Session.where(correlation_id: correlation_id)
      assert_equal 2, events.count
      assert_equal %w[TestClass#method1 TestClass#method2], events.pluck(:name).sort
    end

    test 'flush_events does nothing with empty buffer' do
      configure_timeline do |config|
        config.watch Rails.root.join('app').to_s
      end

      Thread.current[:event_timeline_event_buffer] = []

      assert_no_difference 'Session.count' do
        CallTracker.flush_events('empty-buffer-test')
      end
    end

    test 'flush_events handles errors gracefully' do
      configure_timeline do |config|
        config.watch Rails.root.join('app').to_s
      end

      Thread.current[:event_timeline_event_buffer] = [
        { name: nil, correlation_id: nil }
      ]

      assert_nothing_raised do
        CallTracker.flush_events('error-test')
      end
    end

    test 'determines correlation_id from thread' do
      Thread.current[:request_id] = 'thread-request-123'

      result = CallTracker.send(:determine_correlation_id)
      assert_equal 'thread-request-123', result
    end

    test 'generates UUID when no correlation available' do
      Thread.current[:request_id] = nil
      CurrentCorrelation.reset

      result = CallTracker.send(:determine_correlation_id)

      assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/, result)
    end

    test 'install! enables tracepoints' do
      CallTracker.uninstall!
      refute CallTracker.installed?

      CallTracker.install!
      assert CallTracker.installed?

      CallTracker.uninstall!
      refute CallTracker.installed?
    end

    test 'install! is idempotent' do
      CallTracker.uninstall!

      CallTracker.install!
      first_call_trace = CallTracker.call_trace

      CallTracker.install!
      assert_same first_call_trace, CallTracker.call_trace

      CallTracker.uninstall!
    end

    test 'uninstall! disables tracepoints' do
      CallTracker.install!
      assert CallTracker.installed?

      CallTracker.uninstall!
      refute CallTracker.installed?
      assert_nil CallTracker.call_trace
      assert_nil CallTracker.return_trace
    end
  end
end
