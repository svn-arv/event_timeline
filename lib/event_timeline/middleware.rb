# frozen_string_literal: true

module EventTimeline
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      CurrentCorrelation.id = request.request_id
      Thread.current[:request_id] = request.request_id

      @app.call(env)
    ensure
      CurrentCorrelation.reset
      Thread.current[:request_id] = nil
    end
  end
end
