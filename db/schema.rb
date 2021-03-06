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

ActiveRecord::Schema.define(version: 2022_07_11_160345) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "collections", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "code"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["code"], name: "index_collections_on_code", unique: true
  end

  create_table "datasets", force: :cascade do |t|
    t.string "title"
    t.string "profile"
    t.string "ark"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "work_id"
    t.string "doi"
  end

  create_table "user_collections", force: :cascade do |t|
    t.string "role"
    t.integer "user_id"
    t.integer "collection_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "user_works", force: :cascade do |t|
    t.string "state"
    t.integer "user_id"
    t.integer "work_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "provider"
    t.string "uid"
    t.string "orcid"
    t.integer "default_collection_id"
    t.string "display_name"
    t.string "full_name"
    t.string "family_name"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider"], name: "index_users_on_provider"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["uid"], name: "index_users_on_uid"
  end

  create_table "work_activities", force: :cascade do |t|
    t.text "message"
    t.string "activity_type"
    t.integer "work_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "created_by_user_id"
  end

  create_table "work_activity_notifications", force: :cascade do |t|
    t.integer "work_activity_id"
    t.integer "user_id"
    t.datetime "read_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "works", force: :cascade do |t|
    t.string "title"
    t.string "work_type"
    t.string "state"
    t.integer "collection_id"
    t.integer "created_by_user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "dublin_core"
    t.json "data_cite"
    t.string "profile"
    t.string "ark"
    t.string "doi"
    t.text "location_notes"
    t.text "submission_notes"
    t.string "files_location"
    t.integer "curator_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "datasets", "works"
  add_foreign_key "user_collections", "collections"
  add_foreign_key "user_collections", "users"
  add_foreign_key "user_works", "users"
  add_foreign_key "user_works", "works"
  add_foreign_key "users", "collections", column: "default_collection_id"
  add_foreign_key "work_activities", "users", column: "created_by_user_id"
  add_foreign_key "work_activities", "works"
  add_foreign_key "work_activity_notifications", "users"
  add_foreign_key "work_activity_notifications", "work_activities"
  add_foreign_key "works", "collections"
  add_foreign_key "works", "users", column: "created_by_user_id"
  add_foreign_key "works", "users", column: "curator_user_id"
end
