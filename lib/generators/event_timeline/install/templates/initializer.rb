# frozen_string_literal: true

EventTimeline.configure do |config|
  # Configure which paths to track method calls for.
  # Supports glob patterns and specific file paths.
  #
  # Examples:
  #   config.watch 'app/services'
  #   config.watch 'app/models/order.rb'
  #   config.watch 'lib/payment_processor'
  #
  # config.watch 'app/services'

  # Add additional attributes to filter (beyond the defaults).
  # Default filtered: password, token, secret, key, credential, auth,
  #                   session, cookie, ssn, social_security, credit_card,
  #                   card_number, cvv, pin, private, confidential
  #
  # config.add_filtered_attributes :bank_account, :routing_number

  # Custom PII filtering logic (optional).
  # Return true to filter, false to keep, nil to use default logic.
  #
  # config.filter_pii do |key, value, context|
  #   return true if key.to_s =~ /account_number/
  #   nil # Fall back to default filtering
  # end

  # Customize how events are displayed in the timeline (optional).
  #
  # config.narrator do |event|
  #   case event.name
  #   when /Payment/
  #     "[PAYMENT] #{event.name}"
  #   else
  #     event.name.humanize
  #   end
  # end

  # Data retention settings (defaults shown).
  #
  # config.max_events_per_correlation = 500  # Max events per request
  # config.max_total_events = 10_000         # Max total events stored
  # config.max_event_age = 1.month           # Auto-delete events older than this
end
