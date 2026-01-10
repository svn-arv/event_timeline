# frozen_string_literal: true

module EventTimeline
  class ValueFilter
    FILTERED = '<FILTERED>'

    class << self
      def filter(key, value, context = {})
        if should_filter?(key, value, context)
          filter_sensitive_value(value, context)
        else
          filter_nested(key, value, context)
        end
      end

      private

      def should_filter?(key, value, context)
        EventTimeline.configuration&.should_filter?(key, value, context)
      end

      def filter_sensitive_value(value, context)
        case value
        when String
          FILTERED
        when Hash
          filter_hash(value, context)
        when Array
          filter_array(value, context)
        else
          return filter_activerecord(value) if ValueInspector.activerecord_model?(value)

          FILTERED
        end
      end

      def filter_nested(key, value, context)
        case value
        when Hash
          filter_hash(value, context)
        when Array
          filter_array(value, context)
        else
          return filter_activerecord(value) if ValueInspector.activerecord_model?(value)

          ValueInspector.inspect(value)
        end
      end

      def filter_hash(hash, context = {})
        hash.each_with_object({}) do |(key, value), filtered|
          filtered[key] = filter(key, value, context.merge(context: :hash_value))
        end
      end

      def filter_array(array, context = {})
        array.map.with_index do |item, index|
          filter("item_#{index}", item, context)
        end
      end

      def filter_activerecord(record)
        if should_filter?(:activerecord, record, { context: :model })
          FILTERED
        else
          filter_activerecord_attributes(record)
        end
      rescue StandardError
        "#{ValueInspector.inspect_activerecord(record)} <filtering failed>"
      end

      def filter_activerecord_attributes(record)
        filtered_attrs = record.attributes.each_with_object({}) do |(key, value), attrs|
          attrs[key] = if should_filter?(key, value, { context: :attribute })
                         FILTERED
                       else
                         ValueInspector.inspect(value)
                       end
        end

        "#{ValueInspector.inspect_activerecord(record)} {#{filtered_attrs.map { |k, v| "#{k}: #{v}" }.join(', ')}}"
      end
    end
  end
end
