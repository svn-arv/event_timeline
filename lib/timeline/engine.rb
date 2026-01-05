# frozen_string_literal: true

module Timeline
  class Engine < ::Rails::Engine
    isolate_namespace Timeline

    initializer 'timeline.install_call_tracker' do
      ActiveSupport.on_load(:after_initialize) do
        Timeline::CallTracker.install!
      end
    end

    initializer 'timeline.setup_middleware' do |app|
      app.middleware.use Timeline::Middleware
    end
  end
end
