# frozen_string_literal: true

module Timeline
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
