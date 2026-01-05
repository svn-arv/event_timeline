# frozen_string_literal: true

module EventTimeline
  class SessionsController < ApplicationController
    def show
      @correlation_id = params[:id]
      @events = Session.by_correlation(@correlation_id)
    end
  end
end
