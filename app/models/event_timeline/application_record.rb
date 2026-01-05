# frozen_string_literal: true

module EventTimeline
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
