# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

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

    test 'watched call outside a request buffers nothing' do
      # Nothing flushes outside the middleware, so events here would pile up forever.
      track_calls { TrackedSample.new.double(2) }

      assert_empty buffered_events
    end

    test 'return in an unwatched file never reads the correlation' do
      configure_timeline { |config| config.watch Rails.root.join('app').to_s }
      unwatched_return = Struct.new(:path).new('/not/watched.rb')

      reads = 0
      CurrentCorrelation.stub(:id, -> { reads += 1 }) do
        CallTracker.send(:handle_return, unwatched_return)
      end

      assert_equal 0, reads
    end

    test 'captures params when the receiver overrides method' do
      with_correlation('params-test') do
        track_calls { MethodOverridingSample.new.double(21) }
      end

      call_event = buffered_events.find { |event| event[:category] == 'method_call' }
      assert_equal({ amount: '21' }, call_event[:payload][:params])
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

    private

    def track_calls
      # The runner may load this file by a relative path, which `watch` would make absolute.
      configure_timeline { |config| config.watched_paths << __FILE__ }
      CallTracker.install!
      yield
    ensure
      CallTracker.uninstall!
    end

    def buffered_events
      Thread.current[:event_timeline_event_buffer] || []
    end
  end

  class TrackedSample
    def double(amount) = amount * 2
  end

  class MethodOverridingSample
    def method(*) = raise('nope')

    def double(amount) = amount * 2
  end
end
