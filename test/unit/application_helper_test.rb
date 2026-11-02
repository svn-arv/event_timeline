# frozen_string_literal: true

require 'test_helper'

module EventTimeline
  class ApplicationHelperTest < ActionView::TestCase
    include ApplicationHelper

    setup { EventTimeline.configuration = nil }

    test 'call events keep their raw name so class and method names stay readable' do
      event = Session.new(name: 'OrdersController#with_undefined_method')

      assert_equal 'OrdersController#with_undefined_method', narrate_event(event)
    end
  end
end
