# EventTimeline

A Rails engine that records method calls during requests so you can see what actually happened.

## Why?

You get a bug report: "Order failed for user X". You check the logs, see a 500 error, but the stack trace doesn't tell you what state the app was in or what data was being processed.

EventTimeline records the method calls, parameters, and return values during the request. You visit `/event_timeline/sessions/<request_id>` and see exactly what happened.

## Install

```ruby
gem 'event_timeline'
```

```bash
bundle install
rails generate event_timeline:install
rails db:migrate
```

## Setup

Tell it what to track:

```ruby
# config/initializers/event_timeline.rb
EventTimeline.configure do |config|
  config.watch 'app/services'
  config.watch 'app/models'
end
```

## Usage

Make a request, grab the request ID from logs, visit:

```
/event_timeline/sessions/abc-123-def
```

You'll see the call timeline with params and return values. If the request crashed, you'll see the exception with its source location and backtrace.

## Configuration

```ruby
EventTimeline.configure do |config|
  # What to track
  config.watch 'app/services'
  config.watch 'lib/payments'

  # Filter sensitive params (these are filtered by default: password, token, secret, etc.)
  config.add_filtered_attributes :credit_card, :ssn

  # Custom filtering
  config.filter_pii do |key, value, context|
    key.to_s.include?('account_number') ? true : nil
  end

  # Retention
  config.max_events_per_correlation = 500
  config.max_total_events = 10_000
  config.max_event_age = 1.month

  # Truncation
  config.max_string_length = 100
  config.max_inspect_length = 200
end
```

## Runtime control

```ruby
EventTimeline::CallTracker.uninstall!   # stop tracking
EventTimeline::CallTracker.install!     # start tracking
EventTimeline::CallTracker.installed?   # check status
```

## Custom correlation IDs

For background jobs or anything outside a request:

```ruby
EventTimeline::CurrentCorrelation.id = "import-job-#{job.id}"
```

## Limitations

- Only tracks Ruby method calls (not SQL queries or HTTP calls)
- TracePoint has some overhead - probably don't enable in high-traffic production without sampling
- Large values get truncated

## License

MIT
