# frozen_string_literal: true

module Timeline
  module ApplicationHelper
    def narrate_event(event)
      if Timeline.configuration&.narrator_proc
        Timeline.configuration.narrator_proc.call(event)
      else
        event.name.humanize
      end
    end
  end
end
