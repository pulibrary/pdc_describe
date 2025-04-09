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


ActiveRecord::Schema[8.0].define(version: 2025_04_07_152610) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
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
    t.datetime "created_at", precision: nil, null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "group_options", force: :cascade do |t|
    t.integer "option_type"
    t.integer "option_value"
    t.bigint "group_id"
    t.bigint "user_id"
    t.boolean "enabled", default: true
    t.string "subcommunity"
    t.index ["group_id"], name: "index_group_options_on_group_id"
    t.index ["user_id"], name: "index_group_options_on_user_id"
  end

  create_table "groups", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_groups_on_code", unique: true
  end

  create_table "researchers", force: :cascade do |t|
    t.string "affiliation"
    t.string "affiliation_ror"
    t.string "netid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["first_name"], name: "index_researchers_on_first_name"
    t.index ["last_name"], name: "index_researchers_on_last_name"
    t.index ["orcid"], name: "index_researchers_on_orcid"

  end

  create_table "roles", force: :cascade do |t|
    t.string "name"
    t.string "resource_type"
    t.bigint "resource_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "resource_type", "resource_id"], name: "index_roles_on_name_and_resource_type_and_resource_id"
    t.index ["resource_type", "resource_id"], name: "index_roles_on_resource"
  end

  create_table "upload_snapshots", force: :cascade do |t|
    t.string "url"
    t.bigint "version"
    t.bigint "work_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "files"
    t.string "type"
    t.index ["work_id"], name: "index_upload_snapshots_on_work_id"
  end

  create_table "user_works", force: :cascade do |t|
    t.string "state"
    t.integer "user_id"
    t.integer "work_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider"
    t.string "uid"
    t.string "orcid"
    t.integer "default_group_id"
    t.string "given_name"
    t.string "full_name"
    t.string "family_name"
    t.boolean "email_messages_enabled", default: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider"], name: "index_users_on_provider"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["uid"], name: "index_users_on_uid"
  end

  create_table "users_roles", id: false, force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "role_id"
    t.index ["role_id"], name: "index_users_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_users_roles_on_user_id_and_role_id"
    t.index ["user_id"], name: "index_users_roles_on_user_id"
  end

  create_table "work_activities", force: :cascade do |t|
    t.text "message"
    t.string "activity_type"
    t.integer "work_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "created_by_user_id"
  end

  create_table "work_activity_notifications", force: :cascade do |t|
    t.integer "work_activity_id"
    t.integer "user_id"
    t.datetime "read_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "works", force: :cascade do |t|
    t.string "work_type"
    t.string "state"
    t.integer "group_id"
    t.integer "created_by_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "metadata"
    t.string "profile"
    t.text "location_notes"
    t.text "submission_notes"
    t.string "files_location"
    t.integer "curator_user_id"
    t.date "embargo_date"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "upload_snapshots", "works"
  add_foreign_key "user_works", "users"
  add_foreign_key "user_works", "works"
  add_foreign_key "users", "groups", column: "default_group_id"
  add_foreign_key "work_activities", "users", column: "created_by_user_id"
  add_foreign_key "work_activities", "works"
  add_foreign_key "work_activity_notifications", "users"
  add_foreign_key "work_activity_notifications", "work_activities"
  add_foreign_key "works", "groups"
  add_foreign_key "works", "users", column: "created_by_user_id"
  add_foreign_key "works", "users", column: "curator_user_id"
end
