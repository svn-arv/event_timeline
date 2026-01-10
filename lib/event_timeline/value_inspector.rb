# frozen_string_literal: true

module EventTimeline
  class ValueInspector
    class << self
      def inspect(value)
        return inspect_string(value) if value.is_a?(String)
        return inspect_collection(value) if value.is_a?(Hash) || value.is_a?(Array)
        return inspect_activerecord(value) if activerecord_model?(value)
        return inspect_activemodel(value) if activemodel_model?(value)
        return value.name if value.is_a?(Class) || value.is_a?(Module)

        inspect_generic(value)
      rescue StandardError
        '<inspect failed>'
      end

      def inspect_activerecord(record)
        if record.persisted?
          id_attr = record.class.primary_key
          id_value = record.send(id_attr) if id_attr
          "#{record.class.name}(#{id_attr}: #{id_value})"
        else
          "#{record.class.name}(new_record)"
        end
      rescue StandardError
        "#{record.class.name}(<inspection failed>)"
      end

      def activerecord_model?(value)
        defined?(ActiveRecord::Base) && value.is_a?(ActiveRecord::Base)
      end

      def activemodel_model?(value)
        return false unless defined?(ActiveModel::Model)

        value.class.included_modules.include?(ActiveModel::Model)
      end

      private

      def inspect_string(value)
        max_length = EventTimeline.configuration&.max_string_length || 100
        value.length > max_length ? "#{value[0...max_length]}..." : value
      end

      def inspect_collection(value)
        max_length = EventTimeline.configuration&.max_inspect_length || 200
        inspected = value.inspect
        inspected.length > max_length ? "#{value.class}[#{value.size} items]" : inspected
      end

      def inspect_activemodel(model)
        "#{model.class.name}(#{model.class.attribute_names.size} attributes)"
      rescue StandardError
        "#{model.class.name}(<inspection failed>)"
      end

      def inspect_generic(value)
        max_length = EventTimeline.configuration&.max_inspect_length || 200
        result = value.inspect
        result.length > max_length ? "#{value.class.name}[#{result.length} chars]" : result
      end
    end
  end
end
