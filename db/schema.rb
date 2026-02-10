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

ActiveRecord::Schema[7.1].define(version: 2026_02_10_060722) do
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
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "classroom_memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "classroom_id", null: false
    t.string "role", default: "student", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["classroom_id", "user_id"], name: "index_classroom_memberships_on_classroom_id_and_user_id", unique: true
    t.index ["classroom_id"], name: "index_classroom_memberships_on_classroom_id"
    t.index ["user_id"], name: "index_classroom_memberships_on_user_id"
    t.check_constraint "role::text = ANY (ARRAY['teacher'::character varying, 'student'::character varying]::text[])", name: "chk_cm_role"
  end

  create_table "classrooms", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "compliments", force: :cascade do |t|
    t.bigint "giver_id"
    t.bigint "receiver_id"
    t.bigint "classroom_id", null: false
    t.datetime "given_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["classroom_id", "given_at"], name: "index_compliments_on_classroom_id_and_given_at"
    t.index ["classroom_id", "giver_id", "receiver_id", "given_at"], name: "idx_compliments_dup_guard"
    t.index ["classroom_id"], name: "index_compliments_on_classroom_id"
    t.index ["giver_id"], name: "index_compliments_on_giver_id"
    t.index ["receiver_id"], name: "index_compliments_on_receiver_id"
  end

  create_table "coupon_events", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "actor_id", null: false
    t.bigint "user_coupon_id", null: false
    t.bigint "classroom_id", null: false
    t.bigint "coupon_template_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_coupon_events_on_action"
    t.index ["actor_id"], name: "index_coupon_events_on_actor_id"
    t.index ["classroom_id"], name: "index_coupon_events_on_classroom_id"
    t.index ["coupon_template_id"], name: "index_coupon_events_on_coupon_template_id"
    t.index ["created_at"], name: "index_coupon_events_on_created_at"
    t.index ["user_coupon_id"], name: "index_coupon_events_on_user_coupon_id"
  end

  create_table "coupon_templates", force: :cascade do |t|
    t.string "title", null: false
    t.integer "weight", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.bigint "created_by_id", null: false
    t.string "bucket", default: "personal", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "source_template_id"
    t.string "default_image_key"
    t.index ["active"], name: "index_coupon_templates_on_active"
    t.index ["created_by_id", "bucket", "title"], name: "idx_coupon_templates_owner_bucket_title_uniqueness", unique: true
    t.index ["created_by_id", "bucket"], name: "index_coupon_templates_on_created_by_and_bucket"
    t.index ["created_by_id", "source_template_id"], name: "index_coupon_templates_on_creator_and_source", unique: true, where: "(source_template_id IS NOT NULL)"
    t.index ["created_by_id"], name: "index_coupon_templates_on_created_by_id"
  end

  create_table "user_coupons", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "coupon_template_id", null: false
    t.bigint "classroom_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "issued_at", null: false
    t.datetime "used_at"
    t.bigint "issued_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "issuance_basis", default: "daily", null: false
    t.date "period_start_on", null: false
    t.string "basis_tag"
    t.index ["classroom_id", "issuance_basis", "period_start_on", "basis_tag"], name: "idx_uc_classroom_basis_period_tag"
    t.index ["classroom_id"], name: "index_user_coupons_on_classroom_id"
    t.index ["coupon_template_id"], name: "index_user_coupons_on_coupon_template_id"
    t.index ["issued_at"], name: "index_user_coupons_on_issued_at"
    t.index ["issued_by_id"], name: "index_user_coupons_on_issued_by_id"
    t.index ["used_at"], name: "index_user_coupons_on_used_at"
    t.index ["user_id", "classroom_id", "period_start_on"], name: "idx_user_coupons_daily_period_uniqueness", unique: true, where: "(((issuance_basis)::text = 'daily'::text) AND (status = 0))"
    t.index ["user_id", "classroom_id", "status", "issued_at"], name: "idx_uc_user_classroom_status_issued_at_desc", order: { issued_at: :desc }
    t.index ["user_id", "issuance_basis", "period_start_on"], name: "idx_uc_user_basis_period"
    t.index ["user_id", "issued_at"], name: "idx_uc_user_issued_at_desc", order: { issued_at: :desc }
    t.index ["user_id", "status", "issued_at"], name: "idx_uc_user_status_issued_at_desc", order: { issued_at: :desc }
    t.index ["user_id", "status"], name: "index_user_coupons_on_user_id_and_status"
    t.index ["user_id"], name: "index_user_coupons_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "role", default: "student", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "avatar"
    t.integer "points", default: 0
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "classroom_memberships", "classrooms", on_delete: :cascade
  add_foreign_key "classroom_memberships", "users", on_delete: :cascade
  add_foreign_key "compliments", "classrooms"
  add_foreign_key "compliments", "users", column: "giver_id"
  add_foreign_key "compliments", "users", column: "receiver_id"
  add_foreign_key "coupon_events", "classrooms"
  add_foreign_key "coupon_events", "coupon_templates"
  add_foreign_key "coupon_events", "user_coupons"
  add_foreign_key "coupon_events", "users", column: "actor_id"
  add_foreign_key "coupon_templates", "coupon_templates", column: "source_template_id", on_delete: :nullify
  add_foreign_key "coupon_templates", "users", column: "created_by_id"
  add_foreign_key "user_coupons", "classrooms"
  add_foreign_key "user_coupons", "coupon_templates"
  add_foreign_key "user_coupons", "users"
  add_foreign_key "user_coupons", "users", column: "issued_by_id", on_delete: :nullify
end
