# frozen_string_literal: true

EventTimeline.configure do |config|
  config.watch 'app/controllers'
  config.watch 'app/models'
  config.watch 'app/services'
end
