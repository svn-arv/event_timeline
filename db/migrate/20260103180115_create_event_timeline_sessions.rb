# frozen_string_literal: true

class CreateEventTimelineSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :event_timeline_sessions do |t|
      t.string :name, null: false
      t.string :severity, default: 'info'
      t.string :category
      t.jsonb :payload
      t.string :correlation_id, null: false
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :event_timeline_sessions, :correlation_id
    add_index :event_timeline_sessions, :occurred_at
    add_index :event_timeline_sessions, %i[correlation_id occurred_at]
  end
end
