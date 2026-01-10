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
