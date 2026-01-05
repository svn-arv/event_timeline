# frozen_string_literal: true

module EventTimeline
  class Engine < ::Rails::Engine
    isolate_namespace EventTimeline

    initializer 'timeline.install_call_tracker' do
      ActiveSupport.on_load(:after_initialize) do
        EventTimeline::CallTracker.install!
      end
    end

    initializer 'timeline.setup_middleware' do |app|
      app.middleware.use EventTimeline::Middleware
    end
  end
end
