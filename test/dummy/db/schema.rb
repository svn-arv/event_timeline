# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_10_150122) do
  create_table "event_timeline_sessions", force: :cascade do |t|
    t.string "category"
    t.string "correlation_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "occurred_at", null: false
    t.json "payload"
    t.string "severity", default: "info"
    t.datetime "updated_at", null: false
    t.index ["correlation_id", "occurred_at"], name: "index_event_timeline_sessions_on_correlation_id_and_occurred_at"
    t.index ["correlation_id"], name: "index_event_timeline_sessions_on_correlation_id"
    t.index ["occurred_at"], name: "index_event_timeline_sessions_on_occurred_at"
  end
end
