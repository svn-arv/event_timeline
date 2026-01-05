# frozen_string_literal: true

require 'timeline/version'
require 'timeline/engine'
require 'timeline/configuration'
require 'timeline/current_correlation'
require 'timeline/call_tracker'
require 'timeline/middleware'
require 'timeline/rotation_service'

module Timeline
  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    alias config configure
  end
end
