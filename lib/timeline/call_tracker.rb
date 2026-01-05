# frozen_string_literal: true

module Timeline
  class CallTracker
    class << self
      def install!
        @last_location = {}
        @method_stack = Hash.new { |h, k| h[k] = [] }

        call_trace = TracePoint.new(:call) do |tp|
          next unless Timeline.configuration&.watched?(tp.path)

          current_location = "#{tp.path}:#{tp.lineno}"
          correlation_id = CurrentCorrelation.id || determine_correlation_id

          if @last_location[correlation_id] != current_location
            @last_location[correlation_id] = current_location

            # Capture method arguments
            params = capture_params(tp)

            event_id = SecureRandom.uuid
            @method_stack[correlation_id].push({
                                                 event_id: event_id,
                                                 method: "#{tp.defined_class}##{tp.method_id}"
                                               })

            Session.create!(
              name: "#{tp.defined_class}##{tp.method_id}",
              severity: 'info',
              category: 'method_call',
              payload: {
                event_id: event_id,
                file: tp.path,
                line: tp.lineno,
                class: tp.defined_class.to_s,
                method: tp.method_id.to_s,
                params: params
              },
              correlation_id: correlation_id,
              occurred_at: Time.current
            )

            # Enforce rotation limits
            RotationService.enforce_correlation_limit(correlation_id)
            RotationService.cleanup_if_needed
          end
        rescue StandardError => e
          Rails.logger.error "Timeline call tracking failed: #{e.message}" if defined?(Rails.logger)
        end

        return_trace = TracePoint.new(:return) do |tp|
          next unless Timeline.configuration&.watched?(tp.path)

          correlation_id = CurrentCorrelation.id || determine_correlation_id
          method_info = @method_stack[correlation_id].find { |m| m[:method] == "#{tp.defined_class}##{tp.method_id}" }

          if method_info
            @method_stack[correlation_id].delete(method_info)

            Session.create!(
              name: "#{tp.defined_class}##{tp.method_id}_return",
              severity: 'info',
              category: 'method_return',
              payload: {
                event_id: method_info[:event_id],
                return_value: filter_sensitive_data(:return_value, tp.return_value, { context: :return_value }),
                class: tp.defined_class.to_s,
                method: tp.method_id.to_s
              },
              correlation_id: correlation_id,
              occurred_at: Time.current
            )
          end
        rescue StandardError => e
          Rails.logger.error "Timeline return tracking failed: #{e.message}" if defined?(Rails.logger)
        end

        call_trace.enable
        return_trace.enable
      end

      private

      def capture_params(tp)
        method = tp.self.method(tp.method_id)
        params = {}

        method.parameters.each_value do |name|
          if tp.binding.local_variable_defined?(name)
            value = tp.binding.local_variable_get(name)
            params[name] = filter_sensitive_data(name, value, { context: :parameter })
          end
        end

        params
      rescue StandardError => e
        { error: "Failed to capture params: #{e.message}" }
      end

      def safe_inspect(value)
        case value
        when String
          value.length > 100 ? "#{value[0..100]}..." : value
        when Hash, Array
          value.inspect.length > 200 ? "#{value.class}[#{value.size} items]" : value.inspect
        when defined?(ActiveRecord::Base) && ActiveRecord::Base
          inspect_activerecord(value)
        when defined?(ActiveModel::Model) && ActiveModel::Model
          inspect_model(value)
        when Class
          value.name
        when Module
          value.name
        else
          simple_inspect(value)
        end
      rescue StandardError => e
        "<inspect failed: #{e.message}>"
      end

      def inspect_activerecord(record)
        if record.persisted?
          id_attr = record.class.primary_key
          id_value = record.send(id_attr) if id_attr
          "#{record.class.name}(#{id_attr}: #{id_value})"
        else
          "#{record.class.name}(new_record)"
        end
      rescue StandardError => e
        "#{record.class.name}(<inspection failed>)"
      end

      def inspect_model(model)
        "#{model.class.name}(#{model.class.attribute_names.size} attributes)"
      rescue StandardError => e
        "#{model.class.name}(<inspection failed>)"
      end

      def simple_inspect(value)
        result = value.inspect
        if result.length > 200
          "#{value.class.name}[#{result.length} chars]"
        else
          result
        end
      end

      def filter_sensitive_data(key, value, context = {})
        if Timeline.configuration&.should_filter?(key, value, context)
          case value
          when String
            '<FILTERED>'
          when Hash
            filter_hash(value)
          when Array
            value.map.with_index { |item, index| filter_sensitive_data("item_#{index}", item, context) }
          when defined?(ActiveRecord::Base) && ActiveRecord::Base
            filter_activerecord(value)
          else
            '<FILTERED>'
          end
        else
          safe_inspect(value)
        end
      end

      def filter_hash(hash)
        filtered = {}
        hash.each do |key, value|
          filtered[key] = filter_sensitive_data(key, value, { context: :hash_value })
        end
        filtered
      end

      def filter_activerecord(record)
        if Timeline.configuration&.should_filter?(:activerecord, record, { context: :model })
          '<FILTERED>'
        else
          # Show model with filtered attributes
          filtered_attrs = {}
          record.attributes.each do |key, value|
            filtered_attrs[key] = if Timeline.configuration&.should_filter?(key, value, { context: :attribute })
                                    '<FILTERED>'
                                  else
                                    safe_inspect(value)
                                  end
          end
          "#{inspect_activerecord(record)} {#{filtered_attrs.map { |k, v| "#{k}: #{v}" }.join(', ')}}"
        end
      rescue StandardError => e
        "#{inspect_activerecord(record)} <filtering failed>"
      end

      def determine_correlation_id
        if Thread.current[:request_id]
          Thread.current[:request_id]
        elsif defined?(ActiveJob::Base) && ActiveJob::Base.current_execution&.job_id
          ActiveJob::Base.current_execution.job_id
        else
          SecureRandom.uuid.tap { |id| CurrentCorrelation.id = id }
        end
      end
    end
  end
end
