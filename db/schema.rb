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

ActiveRecord::Schema.define(version: 2021_06_14_170512) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "webhook_endpoints", force: :cascade do |t|
    t.string "url", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "enabled", default: true
    t.jsonb "subscriptions", default: ["*"]
  end

  create_table "webhook_events", force: :cascade do |t|
    t.integer "webhook_endpoint_id", null: false
    t.string "event", null: false
    t.jsonb "payload", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "response", default: {}
    t.index ["webhook_endpoint_id"], name: "index_webhook_events_on_webhook_endpoint_id"
  end

end
