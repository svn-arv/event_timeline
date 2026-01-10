# frozen_string_literal: true

require 'test_helper'

module EventTimeline
  class TrackingTest < IntegrationTestCase
    test 'middleware sets correlation id from request' do
      configure_timeline do |config|
        config.watch 'app/controllers'
      end

      get '/test'

      assert_response :success
      json = JSON.parse(response.body)
      assert json['request_id'].present?
    end

    test 'middleware cleans up thread state after request' do
      configure_timeline do |config|
        config.watch 'app/controllers'
      end

      get '/test'

      assert_nil Thread.current[:request_id]
      assert_nil CurrentCorrelation.id
    end

    test 'events are recorded for watched paths' do
      configure_timeline do |config|
        config.watch 'app/controllers'
      end

      get '/test'

      json = JSON.parse(response.body)
      request_id = json['request_id']

      events = Session.where(correlation_id: request_id)
      assert events.any?, 'Expected events to be recorded'
    end

    test 'events include method call information' do
      configure_timeline do |config|
        config.watch 'app/controllers'
      end

      get '/test'

      json = JSON.parse(response.body)
      request_id = json['request_id']

      event = Session.where(correlation_id: request_id).first
      assert_not_nil event
      assert event.name.present?
      assert event.payload.present?
    end

    test 'middleware handles errors gracefully' do
      configure_timeline do |config|
        config.watch 'app/controllers'
      end

      assert_raises(StandardError) do
        get '/test/error'
      end

      # Thread state should still be cleaned up
      assert_nil Thread.current[:request_id]
    end
  end
end
