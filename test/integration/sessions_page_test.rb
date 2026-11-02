# frozen_string_literal: true

require 'test_helper'

module EventTimeline
  class SessionsPageTest < IntegrationTestCase
    test 'call events are prefixed -> so they mirror the <- of their returns' do
      Session.create!(name: 'OrdersController#show', category: 'method_call', severity: 'info',
                      payload: {}, correlation_id: 'page-test', occurred_at: Time.current)

      get '/event_timeline/sessions/page-test'

      assert_response :success
      assert_includes response.body, '-&gt; OrdersController#show'
    end
  end
end
