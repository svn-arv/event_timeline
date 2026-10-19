## Unreleased

- Events are recorded only while `CurrentCorrelation.id` is set (the middleware sets it per request). Calls in jobs, the console or other threads without it are no longer buffered under a generated id.
- Each request keeps at most `max_events_per_correlation` events in memory. Past the cap, later events are dropped and one `EVENTS TRUNCATED` event (category `truncated`, payload `{ limit: n }`) marks the cut. An exception is always recorded, even past the cap. Earlier versions kept the most recent events instead of the first.
- `RotationService.enforce_correlation_limit` is removed. The in-memory cap replaces it, so flushes no longer run per-request count or delete queries.
- `event_id` in call and return payloads is now an integer sequence per request instead of a UUID.
- Flushing clears the buffer, so a second flush in the same request does not insert the events again.
- `ActiveRecord::Relation` values are shown as `Model::Relation` without running a query, and large arrays and hashes are summarised without being inspected.

# EventTimeline v0.2.1

Performance improvements release.

## Changes

**Watched Path Caching**
- Cache `watched?` lookups to avoid repeated `File.fnmatch?` on every method call
- New `clear_watched_cache!` method to invalidate cache if needed

**Probabilistic Rotation**
- Only run `Session.count` every 100 flushes instead of every request
- Track correlation counts in memory, only query DB when near 90% of limit
- New `RotationService.reset_counters!` method for testing

**TracePoint Optimization**
- Skip redundant `watched?` check in return handler

## Installation

```ruby
gem 'event_timeline', '~> 0.2.1'
```

```bash
bundle update event_timeline
```

---

# EventTimeline v0.2.0

Major refactoring release with exception tracking and improved architecture.

## New Features

**Exception Tracking**
- Automatically captures unhandled exceptions in requests
- Records exception class, message, and cleaned backtrace
- Shows source file, line, and method where exception was raised
- Timeline view displays SUCCESS/FAILED status badge
- Exceptions styled prominently with red highlighting

**Runtime Control**
- New `CallTracker.uninstall!` method to disable tracking at runtime
- New `CallTracker.installed?` method to check tracking status
- Idempotent `install!` - safe to call multiple times

**Configurable Truncation**
- `config.max_string_length` - truncate long strings (default: 100)
- `config.max_inspect_length` - truncate inspected values (default: 200)

## Improvements

**CallTracker Refactoring**
- Fixed recursion handling with proper LIFO stack semantics
- Removed broken deduplication that skipped recursive calls
- Extracted `ValueInspector` class for value inspection
- Extracted `ValueFilter` class for PII filtering
- Fixed `case/when` bug with `defined?` checks

**Code Quality**
- Reduced CallTracker from 257 to 175 lines
- Better separation of concerns
- Improved test coverage (65 tests, 133 assertions)

## Breaking Changes

None - fully backward compatible with v0.1.0

## Installation

```ruby
gem 'event_timeline', '~> 0.2.0'
```

```bash
bundle update event_timeline
```

---

# EventTimeline v0.1.0

Initial release of EventTimeline - a Rails gem for debugging request execution flow.

## What it does

EventTimeline tracks method calls as they happen during a Rails request, then lets you replay the execution timeline through a web UI. This makes it easy to debug production issues, understand unfamiliar code, and trace execution paths.

## Features

**Method tracking**
- Records method calls, parameters, and return values
- Groups events by request ID
- Configurable path watching

**Data protection**
- Automatic PII filtering (passwords, tokens, credit cards)
- Custom filter support
- Safe ActiveRecord inspection

**Performance**
- Automatic data rotation
- Configurable retention limits
- Old event cleanup
- Minimal TracePoint overhead

**Web interface**
- View timelines at `/event_timeline/sessions/:request_id`
- Nested call visualization
- Support for custom correlation IDs

## Installation

```ruby
gem 'event_timeline'
```

```bash
bundle install
rails generate event_timeline:install
rails db:migrate
```

## Basic configuration

```ruby
# config/initializers/event_timeline.rb
EventTimeline.configure do |config|
  config.watch 'app/services'
  config.watch 'app/models'
end
```

## Requirements

- Ruby >= 3.0
- Rails >= 7.0

## Links

- [Documentation](https://github.com/svn-arv/event_timeline)
- [Issues](https://github.com/svn-arv/event_timeline/issues)
