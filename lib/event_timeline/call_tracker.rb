# frozen_string_literal: true

module EventTimeline
  class CallTracker
    THREAD_KEY_METHOD_STACK = :event_timeline_method_stack
    THREAD_KEY_EVENT_BUFFER = :event_timeline_event_buffer
    THREAD_KEY_EVENT_SEQUENCE = :event_timeline_event_sequence

    class << self
      def install!
        return if installed?

        @traces = {}
        ObjectSpace.each_object(Module) do |mod|
          attach(mod) unless deprecated_constant?(mod) || mod.singleton_class?
        rescue StandardError => e
          Rails.logger.warn "EventTimeline could not attach to #{mod.name}: #{e.message}"
        end
        register_autoload_hooks
      end

      def uninstall!
        @traces&.each_value { |traces| traces.each(&:disable) }
        @traces = nil
      end

      def installed?
        !@traces.nil?
      end

      def flush_events(_correlation_id)
        buffer = thread_event_buffer
        return if buffer.empty?

        Session.insert_all(buffer)
        RotationService.cleanup_if_needed
      rescue StandardError => e
        Rails.logger.error "EventTimeline flush failed: #{e.message}" if defined?(Rails.logger)
      ensure
        Thread.current[THREAD_KEY_EVENT_BUFFER] = []
        Thread.current[THREAD_KEY_EVENT_SEQUENCE] = nil
      end

      def cleanup_thread_state(correlation_id)
        thread_method_stack.delete(correlation_id)
        Thread.current[THREAD_KEY_EVENT_BUFFER] = []
        Thread.current[THREAD_KEY_EVENT_SEQUENCE] = nil
      end

      def record_exception(exception, correlation_id)
        backtrace = clean_backtrace(exception.backtrace || [])
        source_location = extract_source_location(backtrace)

        # Bypasses the cap: the exception is the event a capped request most needs.
        thread_event_buffer << {
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
        }
      rescue StandardError => e
        Rails.logger.error "EventTimeline exception recording failed: #{e.message}" if defined?(Rails.logger)
      end

      private

      # Classes loaded or reloaded after boot are attached and detached as Zeitwerk loads them.
      def register_autoload_hooks
        return if @autoload_hooks_registered || !defined?(Rails.autoloaders)

        @autoload_hooks_registered = true
        Rails.autoloaders.main.on_load(:ANY) do |_cpath, value, _abspath|
          attach(value) if installed? && value.is_a?(Module)
        end
        Rails.autoloaders.main.on_unload(:ANY) { |_cpath, value, _abspath| detach(value) if installed? }
      end

      # Rails' deprecated constant proxies print a warning on almost any method call, is_a? included.
      def deprecated_constant?(mod)
        defined?(ActiveSupport::Deprecation::DeprecatedConstantProxy) &&
          Kernel.instance_method(:is_a?).bind_call(mod, ActiveSupport::Deprecation::DeprecatedConstantProxy)
      end

      def attach(mod)
        return if @traces.nil? || @traces.key?(mod)

        @traces[mod] = watched_methods(mod).map do |method|
          TracePoint.new(:call, :return) { |tp| tp.event == :call ? handle_call(tp) : handle_return(tp) }
                    .tap { |trace| trace.enable(target: method) }
        end
      end

      def detach(mod)
        @traces&.delete(mod)&.each(&:disable)
      end

      # Attr methods have no Ruby body to target, and aliases share one, so each body is traced once.
      def watched_methods(mod)
        [mod, mod.singleton_class].flat_map { |owner| own_methods(owner) }.uniq.select do |method|
          RubyVM::InstructionSequence.of(method) && EventTimeline.configuration&.watched?(method.source_location&.first)
        end
      end

      def own_methods(owner)
        names = owner.instance_methods(false) + owner.private_instance_methods(false) +
                owner.protected_instance_methods(false)
        names.map { |name| owner.instance_method(name) }
      end

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
        correlation_id = CurrentCorrelation.id
        return unless correlation_id

        event_id = next_event_id
        signature = method_signature(tp)

        push_to_stack(correlation_id, event_id, signature)
        buffer_call_event(correlation_id, event_id, signature, tp)
      rescue StandardError => e
        Rails.logger.error "EventTimeline call tracking failed: #{e.message}" if defined?(Rails.logger)
      end

      def handle_return(tp)
        correlation_id = CurrentCorrelation.id
        return unless correlation_id

        signature = method_signature(tp)
        method_info = pop_from_stack(correlation_id, signature)
        return unless method_info

        buffer_return_event(correlation_id, method_info, signature, tp)
      rescue StandardError => e
        Rails.logger.error "EventTimeline return tracking failed: #{e.message}" if defined?(Rails.logger)
      end

      def push_to_stack(correlation_id, event_id, signature)
        stack = thread_method_stack[correlation_id] ||= []
        stack.push(
          event_id: event_id,
          method: signature
        )
      end

      def pop_from_stack(correlation_id, signature)
        stack = thread_method_stack[correlation_id]
        return unless stack

        # Find the LAST matching entry (proper LIFO for recursion)
        index = stack.rindex { |m| m[:method] == signature }
        return unless index

        stack.delete_at(index)
      end

      def method_signature(tp)
        "#{tp.defined_class}##{tp.method_id}"
      end

      def buffer_call_event(correlation_id, event_id, signature, tp)
        buffer_event(
          name: signature,
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
          occurred_at: Time.now
        )
      end

      def buffer_return_event(correlation_id, method_info, signature, tp)
        buffer_event(
          name: "#{signature}_return",
          severity: 'info',
          category: 'method_return',
          payload: {
            event_id: method_info[:event_id],
            return_value: ValueFilter.filter(:return_value, tp.return_value, { context: :return_value }),
            class: tp.defined_class.to_s,
            method: tp.method_id.to_s
          },
          correlation_id: correlation_id,
          occurred_at: Time.now
        )
      end

      def thread_method_stack
        Thread.current[THREAD_KEY_METHOD_STACK] ||= {}
      end

      def thread_event_buffer
        Thread.current[THREAD_KEY_EVENT_BUFFER] ||= []
      end

      def next_event_id
        Thread.current[THREAD_KEY_EVENT_SEQUENCE] = (Thread.current[THREAD_KEY_EVENT_SEQUENCE] || 0) + 1
      end

      # Past the per-request cap, keep the earliest events and mark the cut once.
      def buffer_event(event)
        buffer = thread_event_buffer
        limit = EventTimeline.configuration&.max_events_per_correlation
        if limit.nil? || buffer.size < limit
          buffer << event
        elsif buffer.size == limit
          buffer << { name: 'EVENTS TRUNCATED', severity: 'warn', category: 'truncated', payload: { limit: limit },
                      correlation_id: event[:correlation_id], occurred_at: event[:occurred_at] }
        end
      end

      def capture_params(tp)
        params = {}

        tp.parameters.each do |_type, name|
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
    end
  end
end
