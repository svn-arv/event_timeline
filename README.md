# Timeline

Ever wished you could replay what happened during a request? Timeline tracks method calls in your Rails app so you can see exactly how your code executed.

## What it does

Timeline records method calls and returns as they happen, letting you:

- See the exact sequence of method calls during a request
- Inspect parameters passed to each method
- View return values
- Track execution flow across multiple services
- Debug production issues by replaying what actually happened

## Installation

Add to your Gemfile:

```ruby
gem 'timeline'
```

Then:

```bash
bundle install
rails generate timeline:install
rails db:migrate
```

## Basic Usage

### 1. Configure what to track

```ruby
# config/initializers/timeline.rb
Timeline.configure do |config|
  # Track specific paths
  config.watch 'app/services'
  config.watch 'app/models/order.rb'
  config.watch 'lib/payment_processor'
end
```

### 2. View the timeline

Visit `/timeline/sessions/:request_id` to see what happened during any request.

Example: Your logs show request ID `abc-123-def` failed? Go to `/timeline/sessions/abc-123-def` and see every method that was called.

## Real-world Example

Let's say a payment fails in production. Here's what you'd see:

```
OrdersController#create
  Order#initialize
    Order#validate_items
    Order#calculate_total
  Order#save
  PaymentService#charge
    PaymentGateway#create_charge
      <- Returns: {error: "Insufficient funds"}
    PaymentService#handle_failure
      Order#mark_as_failed
      CustomerMailer#payment_failed
```

Now you know exactly where things went wrong and what data was involved.

## Configuration Options

```ruby
Timeline.configure do |config|
  # Filter sensitive data
  config.add_filtered_attributes :credit_card, :ssn, :api_key

  # Custom PII filtering
  config.filter_pii do |key, value|
    return '<REDACTED>' if key.to_s =~ /bank_account/
  end

  # Customize how events are described
  config.narrator do |event|
    case event.name
    when /Stripe/
      "[PAYMENT] #{event.name}"
    else
      event.name
    end
  end

  # Data retention (defaults shown)
  config.max_events_per_correlation = 500     # Per request
  config.max_total_events = 10_000            # Total stored
  config.max_event_age = 1.month              # Auto-delete after
end
```

## Performance

Timeline uses TracePoint which has minimal overhead. Data is automatically rotated to prevent unbounded growth:

- Old events are deleted after 1 month
- Per-request events are capped at 500
- Total events are capped at 10,000

## Pro Tips

1. **Production Debugging**: When users report issues, ask for their request ID from the logs. Timeline will show you exactly what happened.

2. **Development**: Watch your code execute in real-time. Great for understanding unfamiliar codebases.

3. **Testing**: Verify your code follows the expected execution path.

4. **Correlation IDs**: Timeline automatically groups events by request ID, but you can set custom correlation IDs:
   ```ruby
   Timeline::CurrentCorrelation.id = "import-job-#{job.id}"
   ```

## Limitations

- Only tracks Ruby method calls (not database queries or external HTTP calls)
- TracePoint doesn't work with some metaprogramming techniques
- Large payloads are truncated to keep storage reasonable

## License

MIT
