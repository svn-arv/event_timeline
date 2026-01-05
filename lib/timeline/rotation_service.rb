# frozen_string_literal: true

module Timeline
  class RotationService
    class << self
      def cleanup_if_needed
        return unless Timeline.configuration

        total_count = Session.count
        max_total = Timeline.configuration.max_total_events
        threshold = (max_total * Timeline.configuration.cleanup_threshold).to_i

        return unless total_count >= threshold

        perform_cleanup(total_count, max_total)
      end

      def enforce_correlation_limit(correlation_id)
        return unless Timeline.configuration

        max_per_correlation = Timeline.configuration.max_events_per_correlation
        current_count = Session.where(correlation_id: correlation_id).count

        return unless current_count >= max_per_correlation

        # Remove oldest events for this correlation, keeping last 80%
        keep_count = (max_per_correlation * 0.8).to_i
        oldest_events = Session.where(correlation_id: correlation_id)
                               .order(:occurred_at)
                               .limit(current_count - keep_count)

        Session.where(id: oldest_events.pluck(:id)).delete_all

        Rails.logger.info "Timeline: Rotated #{current_count - keep_count} events for correlation #{correlation_id}" if defined?(Rails.logger)
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
        max_age = Timeline.configuration.max_event_age
        cutoff_date = max_age.ago
        old_events_count = Session.where('occurred_at < ?', cutoff_date).delete_all

        Rails.logger.info "Timeline: Cleaned up #{events_to_remove + old_events_count} events" if defined?(Rails.logger)
      end
    end
  end
end
