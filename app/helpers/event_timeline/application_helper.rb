# frozen_string_literal: true

module EventTimeline
  module ApplicationHelper
    def narrate_event(event)
      if EventTimeline.configuration&.narrator_proc
        EventTimeline.configuration.narrator_proc.call(event)
      else
        event.name.humanize
      end
    end
  end
end
