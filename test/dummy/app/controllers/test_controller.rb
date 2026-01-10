# frozen_string_literal: true

class TestController < ApplicationController
  def index
    result = process_data({ name: 'Test', value: 42 })
    render json: { status: 'ok', result: result, request_id: request.request_id }
  end

  def error
    raise StandardError, 'Test error'
  end

  private

  def process_data(data)
    validate_data(data)
    transform_data(data)
  end

  def validate_data(data)
    raise ArgumentError, 'Name required' unless data[:name]
    true
  end

  def transform_data(data)
    { processed: true, original: data }
  end
end
