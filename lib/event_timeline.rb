# frozen_string_literal: true

require 'event_timeline/version'
require 'event_timeline/engine'
require 'event_timeline/configuration'
require 'event_timeline/current_correlation'
require 'event_timeline/value_inspector'
require 'event_timeline/value_filter'
require 'event_timeline/call_tracker'
require 'event_timeline/middleware'
require 'event_timeline/rotation_service'

module EventTimeline
  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    alias config configure
  end
end
