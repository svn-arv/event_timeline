# frozen_string_literal: true

module EventTimeline
  class CallTracker
    THREAD_KEY_METHOD_STACK = :event_timeline_method_stack
    THREAD_KEY_EVENT_BUFFER = :event_timeline_event_buffer

    class << self
      attr_reader :call_trace, :return_trace

      def install!
        return if installed?

        @call_trace = TracePoint.new(:call) { |tp| handle_call(tp) }
        @return_trace = TracePoint.new(:return) { |tp| handle_return(tp) }

        @call_trace.enable
        @return_trace.enable
      end

      def uninstall!
        @call_trace&.disable
        @return_trace&.disable
        @call_trace = nil
        @return_trace = nil
      end

      def installed?
        @call_trace&.enabled? || @return_trace&.enabled?
      end

      def flush_events(correlation_id)
        buffer = thread_event_buffer
        return if buffer.empty?

        Session.insert_all(buffer)

        RotationService.enforce_correlation_limit(correlation_id)
        RotationService.cleanup_if_needed
      rescue StandardError => e
        Rails.logger.error "EventTimeline flush failed: #{e.message}" if defined?(Rails.logger)
      end

      def cleanup_thread_state(correlation_id)
        thread_method_stack.delete(correlation_id)
        Thread.current[THREAD_KEY_EVENT_BUFFER] = []
      end

      def record_exception(exception, correlation_id)
        backtrace = clean_backtrace(exception.backtrace || [])
        source_location = extract_source_location(backtrace)

        buffer_event(
          name: "EXCEPTION: #{exception.class.name}",
          severity: 'error',
          category: 'exception',
          payload: {
            exception_class: exception.class.name,
            message: exception.message,
            backtrace: backtrace.first(10),
            source_file: source_location[:file],
            source_line: source_location[:line],
            source_method: source_location[:method]
          },
          correlation_id: correlation_id,
          occurred_at: Time.current
        )
      rescue StandardError => e
        Rails.logger.error "EventTimeline exception recording failed: #{e.message}" if defined?(Rails.logger)
      end

      private

      def clean_backtrace(backtrace)
        # Filter out gem internals, keep app code
        backtrace.reject { |line| line.include?('/gems/') || line.include?('/ruby/') }
      end

      def extract_source_location(backtrace)
        return { file: nil, line: nil, method: nil } if backtrace.empty?

        # Parse first line: "/path/to/file.rb:123:in `method_name'"
        if backtrace.first =~ /\A(.+):(\d+):in `(.+)'\z/
          { file: ::Regexp.last_match(1), line: ::Regexp.last_match(2).to_i, method: ::Regexp.last_match(3) }
        else
          { file: backtrace.first, line: nil, method: nil }
        end
      end

      def handle_call(tp)
        return unless EventTimeline.configuration&.watched?(tp.path)

        correlation_id = CurrentCorrelation.id || determine_correlation_id
        event_id = SecureRandom.uuid

        push_to_stack(correlation_id, event_id, tp)
        buffer_call_event(correlation_id, event_id, tp)
      rescue StandardError => e
        Rails.logger.error "EventTimeline call tracking failed: #{e.message}" if defined?(Rails.logger)
      end

      def handle_return(tp)
        return unless EventTimeline.configuration&.watched?(tp.path)

        correlation_id = CurrentCorrelation.id || determine_correlation_id
        method_info = pop_from_stack(correlation_id, tp)
        return unless method_info

        buffer_return_event(correlation_id, method_info, tp)
      rescue StandardError => e
        Rails.logger.error "EventTimeline return tracking failed: #{e.message}" if defined?(Rails.logger)
      end

      def push_to_stack(correlation_id, event_id, tp)
        stack = thread_method_stack[correlation_id] ||= []
        stack.push(
          event_id: event_id,
          method: method_signature(tp)
        )
      end

      def pop_from_stack(correlation_id, tp)
        stack = thread_method_stack[correlation_id]
        return unless stack

        signature = method_signature(tp)

        # Find the LAST matching entry (proper LIFO for recursion)
        index = stack.rindex { |m| m[:method] == signature }
        return unless index

        stack.delete_at(index)
      end

      def method_signature(tp)
        "#{tp.defined_class}##{tp.method_id}"
      end

      def buffer_call_event(correlation_id, event_id, tp)
        buffer_event(
          name: method_signature(tp),
          severity: 'info',
          category: 'method_call',
          payload: {
            event_id: event_id,
            file: tp.path,
            line: tp.lineno,
            class: tp.defined_class.to_s,
            method: tp.method_id.to_s,
            params: capture_params(tp)
          },
          correlation_id: correlation_id,
          occurred_at: Time.current
        )
      end

      def buffer_return_event(correlation_id, method_info, tp)
        buffer_event(
          name: "#{method_signature(tp)}_return",
          severity: 'info',
          category: 'method_return',
          payload: {
            event_id: method_info[:event_id],
            return_value: ValueFilter.filter(:return_value, tp.return_value, { context: :return_value }),
            class: tp.defined_class.to_s,
            method: tp.method_id.to_s
          },
          correlation_id: correlation_id,
          occurred_at: Time.current
        )
      end

      def thread_method_stack
        Thread.current[THREAD_KEY_METHOD_STACK] ||= {}
      end

      def thread_event_buffer
        Thread.current[THREAD_KEY_EVENT_BUFFER] ||= []
      end

      def buffer_event(event)
        thread_event_buffer << event
      end

      def capture_params(tp)
        method = tp.self.method(tp.method_id)
        params = {}

        method.parameters.each do |_type, name|
          next unless name

          if tp.binding.local_variable_defined?(name)
            value = tp.binding.local_variable_get(name)
            params[name] = ValueFilter.filter(name, value, { context: :parameter })
          end
        end

        params
      rescue StandardError => e
        { error: "Failed to capture params: #{e.message}" }
      end

      def determine_correlation_id
        if Thread.current[:request_id]
          Thread.current[:request_id]
        elsif Thread.current[:active_job_id]
          Thread.current[:active_job_id]
        else
          SecureRandom.uuid.tap { |id| CurrentCorrelation.id = id }
        end
      end
    end
  end
end
