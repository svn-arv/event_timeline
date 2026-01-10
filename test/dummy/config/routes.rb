# frozen_string_literal: true

Rails.application.routes.draw do
  mount EventTimeline::Engine => '/event_timeline'

  get 'test', to: 'test#index'
  get 'test/error', to: 'test#error'
  get 'up', to: 'rails/health#show', as: :rails_health_check
end
