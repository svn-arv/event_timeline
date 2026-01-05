# frozen_string_literal: true

module Timeline
  class Session < ApplicationRecord
    self.table_name = 'timeline_sessions'

    validates :name, presence: true
    validates :correlation_id, presence: true
    validates :occurred_at, presence: true

    scope :by_correlation, ->(id) { where(correlation_id: id).order(occurred_at: :asc) }
  end
end
