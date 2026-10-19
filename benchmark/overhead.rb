# frozen_string_literal: true

# Measures what the CallTracker TracePoints cost, tracker OFF vs ON.
# Run from the gem root: bundle exec ruby benchmark/overhead.rb
ENV['RAILS_ENV'] = 'test'
require_relative '../test/dummy/config/environment'
require 'benchmark'

class ActiveRecord::Migration
  def self.check_all_pending!; end
end

Tracker = EventTimeline::CallTracker

def unwatched(value)
  value
end

def reset_buffers
  Thread.current[:event_timeline_event_buffer] = []
  Thread.current[:event_timeline_method_stack] = nil
end

# Runs the block once to warm up, then OFF and ON; returns seconds for each.
def measure
  yield
  [false, true].map do |on|
    on ? Tracker.install! : Tracker.uninstall!
    reset_buffers
    Benchmark.realtime { yield }
  end
ensure
  Tracker.uninstall!
end

rows = []
EventTimeline::CurrentCorrelation.id = 'bench'

n = 1_000_000
off, on = measure { n.times { unwatched(1) } }
rows << ['Unwatched call (ns/call)', off * 1e9 / n, on * 1e9 / n]

n = 100_000
off, on = measure do
  n.times do |i|
    reset_buffers if (i % 10_000).zero?
    CalculatorService.add(1, 2)
  end
end
rows << ['Watched call (us/call)', off * 1e6 / n, on * 1e6 / n]

# Flush has no OFF variant: it only runs when the tracker is on.
# The tracker stays installed during the flush, as it does in the middleware.
Tracker.install!
runs = 20
total = 0.0
(runs + 1).times do |run|
  # Events carry CurrentCorrelation.id, so match it to the flushed id for the rotation check.
  EventTimeline::CurrentCorrelation.id = "bench-flush-#{run}"
  reset_buffers
  250.times { CalculatorService.add(1, 2) }
  elapsed = Benchmark.realtime { Tracker.flush_events("bench-flush-#{run}") }
  total += elapsed unless run.zero?
  EventTimeline::Session.delete_all
end
Tracker.uninstall!
flush_ms = total * 1e3 / runs

n = 300
app = Rack::MockRequest.new(Rails.application)
off, on = measure do
  n.times { raise 'GET /test failed' unless app.get('/test').status == 200 }
end
EventTimeline::Session.delete_all
rows << ['Full request GET /test (ms/req)', off * 1e3 / n, on * 1e3 / n]

puts format('%-34s %12s %12s %10s', 'Scenario', 'OFF', 'ON', 'ON/OFF')
rows.each { |name, o, i| puts format('%-34s %12.3f %12.3f %9.2fx', name, o, i, i / o) }
puts format('%-34s %12s %12.3f', 'Flush 500 events (ms/flush)', '-', flush_ms)
puts format('Request overhead: %.3f ms', rows.last[2] - rows.last[1])
