# frozen_string_literal: true

EventTimeline::Engine.routes.draw do
  resources :sessions, only: [:show]
end
