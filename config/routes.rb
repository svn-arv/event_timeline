# frozen_string_literal: true

Timeline::Engine.routes.draw do
  resources :sessions, only: [:show]
end
