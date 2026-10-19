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

      def reset_counters!
        @flush_counter = 0
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
