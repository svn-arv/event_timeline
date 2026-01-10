# frozen_string_literal: true

module EventTimeline
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      correlation_id = request.request_id
      CurrentCorrelation.id = correlation_id
      Thread.current[:request_id] = correlation_id

      @app.call(env)
    rescue Exception => e # rubocop:disable Lint/RescueException
      # Capture the exception before re-raising
      CallTracker.record_exception(e, correlation_id) if correlation_id
      raise
    ensure
      # Flush buffered events to database
      CallTracker.flush_events(correlation_id) if correlation_id

      # Clean up thread-local state
      CallTracker.cleanup_thread_state(correlation_id) if correlation_id
      CurrentCorrelation.reset
      Thread.current[:request_id] = nil
    end
  end
end
