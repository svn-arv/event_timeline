# frozen_string_literal: true

module EventTimeline
  class RotationService
    CLEANUP_CHECK_INTERVAL = 100 # Only check every N flushes

    class << self
      def cleanup_if_needed(force: false)
        return unless EventTimeline.configuration

        unless force
          # Probabilistic check - only run expensive Session.count every N requests
          @flush_counter ||= 0
          @flush_counter += 1
          return unless (@flush_counter % CLEANUP_CHECK_INTERVAL).zero?
        end

        total_count = Session.count
        max_total = EventTimeline.configuration.max_total_events
        threshold = (max_total * EventTimeline.configuration.cleanup_threshold).to_i

        return unless total_count >= threshold

        perform_cleanup(total_count, max_total)
      end

      def enforce_correlation_limit(correlation_id, buffer_size = 0, force: false)
        return unless EventTimeline.configuration

        max_per_correlation = EventTimeline.configuration.max_events_per_correlation

        unless force
          # Track in-memory counts to avoid DB query on every flush
          @correlation_counts ||= {}
          @correlation_counts[correlation_id] ||= 0
          @correlation_counts[correlation_id] += buffer_size

          # Only hit DB when we think we might be near the limit
          return unless @correlation_counts[correlation_id] >= (max_per_correlation * 0.9)
        end

        current_count = Session.where(correlation_id: correlation_id).count
        @correlation_counts[correlation_id] = current_count if @correlation_counts # Sync with reality

        return unless current_count >= max_per_correlation

        # Remove oldest events for this correlation, keeping last 80%
        keep_count = (max_per_correlation * 0.8).to_i
        oldest_events = Session.where(correlation_id: correlation_id)
                               .order(:occurred_at)
                               .limit(current_count - keep_count)

        Session.where(id: oldest_events.pluck(:id)).delete_all
        @correlation_counts[correlation_id] = keep_count if @correlation_counts

        Rails.logger.info "EventTimeline: Rotated #{current_count - keep_count} events for correlation #{correlation_id}" if defined?(Rails.logger)
      end

      def reset_counters!
        @flush_counter = 0
        @correlation_counts = {}
      end

      private

      def perform_cleanup(current_count, max_count)
        # Calculate how many events to remove
        target_count = (max_count * 0.7).to_i # Remove down to 70% of max
        events_to_remove = current_count - target_count

        # Remove oldest events first
        oldest_events = Session.order(:occurred_at).limit(events_to_remove)
        Session.where(id: oldest_events.pluck(:id)).delete_all

        # Also clean up very old events based on configured age
        max_age = EventTimeline.configuration.max_event_age
        cutoff_date = max_age.ago
        old_events_count = Session.where('occurred_at < ?', cutoff_date).delete_all

        Rails.logger.info "EventTimeline: Cleaned up #{events_to_remove + old_events_count} events" if defined?(Rails.logger)
      end
    end
  end
end
