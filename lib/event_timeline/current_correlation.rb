# frozen_string_literal: true

module EventTimeline
  class CurrentCorrelation < ActiveSupport::CurrentAttributes
    attribute :id
  end
end
