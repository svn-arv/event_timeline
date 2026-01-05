# frozen_string_literal: true

module Timeline
  class Configuration
    attr_accessor :narrator_proc, :watched_paths, :pii_filter_proc, :filtered_attributes,
                  :max_events_per_correlation, :max_total_events, :cleanup_threshold, :max_event_age

    def initialize
      @watched_paths = []
      @filtered_attributes = default_filtered_attributes
      @max_events_per_correlation = 500 # Max events per correlation_id
      @max_total_events = 10_000 # Max total events before cleanup
      @cleanup_threshold = 0.8           # Start cleanup at 80% of max
      @max_event_age = 1.month           # Delete events older than this
    end

    def narrator(&block)
      @narrator_proc = block if block_given?
    end

    def watch(path)
      @watched_paths << normalize_path(path)
    end

    def watched?(file_path)
      return false if @watched_paths.empty?

      @watched_paths.any? do |pattern|
        File.fnmatch?(pattern, file_path, File::FNM_PATHNAME)
      end
    end

    def filter_pii(&block)
      @pii_filter_proc = block if block_given?
    end

    def add_filtered_attributes(*attrs)
      @filtered_attributes.concat(attrs.map(&:to_s))
    end

    def remove_filtered_attributes(*attrs)
      attrs.each { |attr| @filtered_attributes.delete(attr.to_s) }
    end

    def should_filter?(key, value, context = {})
      key_str = key.to_s.downcase

      # Check custom filter first
      if @pii_filter_proc
        result = @pii_filter_proc.call(key, value, context)
        return result unless result.nil?
      end

      # Default filtering logic
      @filtered_attributes.any? { |attr| key_str.include?(attr) }
    end

    private

    def default_filtered_attributes
      %w[
        password
        token
        secret
        key
        credential
        auth
        session
        cookie
        ssn
        social_security
        credit_card
        card_number
        cvv
        pin
        private
        confidential
      ]
    end

    def normalize_path(path)
      path = path.to_s
      path = "#{Rails.root}/#{path}" unless path.start_with?('/')
      "#{path.gsub(%r{/$}, '')}/**/*.rb" unless path.include?('*')
    end
  end
end
