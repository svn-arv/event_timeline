# frozen_string_literal: true

module Timeline
  class CurrentCorrelation < ActiveSupport::CurrentAttributes
    attribute :id
  end
end
