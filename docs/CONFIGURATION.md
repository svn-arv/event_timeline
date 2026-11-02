# Configuration

Every option EventTimeline accepts, plus runtime control and custom correlation IDs.

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

Methods are attached when their class loads, so configure `watch` before boot. To pick up paths added later, run `uninstall!` then `install!`.

## Custom correlation IDs

For background jobs or anything outside a request:

```ruby
EventTimeline::CurrentCorrelation.id = "import-job-#{job.id}"
```
