# frozen_string_literal: true

module EventTimeline
  class Engine < ::Rails::Engine
    isolate_namespace EventTimeline

    initializer 'event_timeline.setup_middleware' do |app|
      app.middleware.use EventTimeline::Middleware
    end

    config.after_initialize do
      EventTimeline::CallTracker.install! if EventTimeline.configuration
    end
  end
end
