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

ActiveRecord::Schema[8.1].define(version: 2026_01_24_073922) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "authors_books", id: false, force: :cascade do |t|
    t.uuid "author_id", null: false
    t.uuid "book_id", null: false
    t.index ["author_id", "book_id"], name: "index_authors_books_on_author_id_and_book_id"
    t.index ["book_id", "author_id"], name: "index_authors_books_on_book_id_and_author_id"
  end

  create_table "books", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "author", null: false
    t.datetime "created_at", null: false
    t.string "emoji"
    t.string "isbn"
    t.string "open_library_key"
    t.uuid "post_id"
    t.string "public_id"
    t.integer "rating"
    t.datetime "read_at"
    t.integer "reading_status", default: 2, null: false
    t.uuid "site_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id"], name: "index_books_on_post_id"
    t.index ["public_id"], name: "index_books_on_public_id", unique: true
    t.index ["reading_status"], name: "index_books_on_reading_status"
    t.index ["site_id"], name: "index_books_on_site_id"
  end

  create_table "deployment_targets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "encrypted_config"
    t.string "provider", null: false
    t.string "public_hostname", null: false
    t.string "public_id", limit: 21, null: false
    t.uuid "site_id", null: false
    t.integer "type", null: false
    t.datetime "updated_at", null: false
    t.index ["provider"], name: "index_deployment_targets_on_provider"
    t.index ["public_hostname"], name: "index_deployment_targets_on_public_hostname", unique: true
    t.index ["public_id"], name: "index_deployment_targets_on_public_id", unique: true
    t.index ["site_id"], name: "index_deployment_targets_on_site_id"
    t.index ["type"], name: "index_deployment_targets_on_type"
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "callback_priority"
    t.text "callback_queue_name"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discarded_at"
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
    t.text "on_discard"
    t.text "on_finish"
    t.text "on_success"
    t.jsonb "serialized_properties"
    t.datetime "updated_at", null: false
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id", null: false
    t.datetime "created_at", null: false
    t.interval "duration"
    t.text "error"
    t.text "error_backtrace", array: true
    t.integer "error_event", limit: 2
    t.datetime "finished_at"
    t.text "job_class"
    t.uuid "process_id"
    t.text "queue_name"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "lock_type", limit: 2
    t.jsonb "state"
    t.datetime "updated_at", null: false
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "key"
    t.datetime "updated_at", null: false
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id"
    t.uuid "batch_callback_id"
    t.uuid "batch_id"
    t.text "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "cron_at"
    t.text "cron_key"
    t.text "error"
    t.integer "error_event", limit: 2
    t.integer "executions_count"
    t.datetime "finished_at"
    t.boolean "is_discrete"
    t.text "job_class"
    t.text "labels", array: true
    t.datetime "locked_at"
    t.uuid "locked_by_id"
    t.datetime "performed_at"
    t.integer "priority"
    t.text "queue_name"
    t.uuid "retried_good_job_id"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at", where: "((retried_good_job_id IS NULL) AND (finished_at IS NOT NULL))"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "created_at"], name: "index_good_jobs_jobs_on_priority_created_at_when_unfinished", order: { priority: "DESC NULLS LAST" }, where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at"], name: "index_good_jobs_on_priority_scheduled_at_unfinished_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "images", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "imageable_id"
    t.string "imageable_type"
    t.string "public_id", limit: 21, null: false
    t.uuid "site_id", null: false
    t.string "source_url"
    t.integer "state"
    t.jsonb "unsplash_data"
    t.datetime "updated_at", null: false
    t.index ["imageable_type", "imageable_id"], name: "index_images_on_imageable"
    t.index ["public_id"], name: "index_images_on_public_id", unique: true
    t.index ["site_id"], name: "index_images_on_site_id"
    t.index ["unsplash_data"], name: "index_images_on_unsplash_data", using: :gin
  end

  create_table "navigation_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "navigation_id", null: false
    t.uuid "page_id", null: false
    t.integer "position"
    t.string "public_id"
    t.datetime "updated_at", null: false
    t.index ["navigation_id", "position"], name: "index_navigation_items_on_navigation_id_and_position", unique: true
    t.index ["navigation_id"], name: "index_navigation_items_on_navigation_id"
    t.index ["page_id"], name: "index_navigation_items_on_page_id"
    t.index ["public_id"], name: "index_navigation_items_on_public_id", unique: true
  end

  create_table "navigations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "public_id", limit: 21
    t.uuid "site_id", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_navigations_on_public_id", unique: true
    t.index ["site_id"], name: "index_navigations_on_site_id"
  end

  create_table "pages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.json "content"
    t.datetime "created_at", null: false
    t.string "emoji"
    t.uuid "header_image_id"
    t.integer "page_type", default: 0, null: false
    t.string "public_id", limit: 21, null: false
    t.uuid "site_id", null: false
    t.string "slug"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["header_image_id"], name: "index_pages_on_header_image_id"
    t.index ["public_id"], name: "index_pages_on_public_id", unique: true
    t.index ["site_id"], name: "index_pages_on_site_id"
    t.index ["slug", "site_id"], name: "index_pages_on_slug_and_site_id", unique: true
  end

  create_table "posts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.json "content"
    t.datetime "created_at", null: false
    t.boolean "draft", default: false, null: false
    t.string "emoji"
    t.uuid "header_image_id"
    t.string "public_id", limit: 21, null: false
    t.datetime "publish_at"
    t.uuid "site_id", null: false
    t.string "slug"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["draft"], name: "index_posts_on_draft"
    t.index ["header_image_id"], name: "index_posts_on_header_image_id"
    t.index ["public_id"], name: "index_posts_on_public_id", unique: true
    t.index ["publish_at"], name: "index_posts_on_publish_at"
    t.index ["site_id"], name: "index_posts_on_site_id"
    t.index ["slug", "site_id"], name: "index_posts_on_slug_and_site_id", unique: true
  end

  create_table "projects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "company"
    t.json "content"
    t.datetime "created_at", null: false
    t.string "emoji"
    t.date "ended_at"
    t.uuid "header_image_id"
    t.json "links"
    t.string "period"
    t.integer "project_type"
    t.string "public_id", limit: 21, null: false
    t.string "role"
    t.text "short_description", null: false
    t.uuid "site_id", null: false
    t.string "slug", null: false
    t.date "started_at", null: false
    t.integer "status", default: 0
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["header_image_id"], name: "index_projects_on_header_image_id"
    t.index ["public_id"], name: "index_projects_on_public_id", unique: true
    t.index ["site_id"], name: "index_projects_on_site_id"
    t.index ["slug", "site_id"], name: "index_projects_on_slug_and_site_id", unique: true
    t.index ["started_at"], name: "index_projects_on_started_at"
  end

  create_table "site_users", force: :cascade do |t|
    t.string "public_id", limit: 21, null: false
    t.string "role", default: "editor", null: false
    t.uuid "site_id", null: false
    t.uuid "user_id", null: false
    t.index ["public_id"], name: "index_site_users_on_public_id", unique: true
    t.index ["role"], name: "index_site_users_on_role"
    t.index ["site_id"], name: "index_site_users_on_site_id"
    t.index ["user_id", "site_id"], name: "index_site_users_on_user_id_and_site_id", unique: true
    t.index ["user_id"], name: "index_site_users_on_user_id"
  end

  create_table "sites", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "copyright", default: "© All rights reserved."
    t.datetime "created_at", null: false
    t.string "domain"
    t.string "emoji", limit: 4, default: "🌐"
    t.string "language_code", default: "en", null: false
    t.string "public_id", limit: 21, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["domain"], name: "index_sites_on_domain", unique: true
    t.index ["public_id"], name: "index_sites_on_public_id", unique: true
  end

  create_table "social_media_links", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "icon"
    t.string "name"
    t.string "public_id", limit: 21
    t.uuid "site_id", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["public_id"], name: "index_social_media_links_on_public_id", unique: true
    t.index ["site_id"], name: "index_social_media_links_on_site_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "user_invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "accepted_at", precision: nil
    t.datetime "created_at", null: false
    t.string "email"
    t.uuid "inviting_user_id", null: false
    t.string "public_id"
    t.uuid "site_id", null: false
    t.datetime "updated_at", null: false
    t.index ["accepted_at"], name: "index_user_invitations_on_accepted_at"
    t.index ["email", "site_id"], name: "index_user_invitations_on_email_and_site_id", unique: true
    t.index ["inviting_user_id"], name: "index_user_invitations_on_inviting_user_id"
    t.index ["public_id"], name: "index_user_invitations_on_public_id", unique: true
    t.index ["site_id"], name: "index_user_invitations_on_site_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "last_login_at"
    t.string "public_id", limit: 21, null: false
    t.boolean "super_admin", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["public_id"], name: "index_users_on_public_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "books", "posts"
  add_foreign_key "books", "sites"
  add_foreign_key "deployment_targets", "sites"
  add_foreign_key "images", "sites"
  add_foreign_key "navigation_items", "navigations"
  add_foreign_key "navigation_items", "pages"
  add_foreign_key "navigations", "sites"
  add_foreign_key "pages", "images", column: "header_image_id"
  add_foreign_key "pages", "sites"
  add_foreign_key "posts", "images", column: "header_image_id"
  add_foreign_key "posts", "sites"
  add_foreign_key "projects", "images", column: "header_image_id"
  add_foreign_key "projects", "sites"
  add_foreign_key "site_users", "sites"
  add_foreign_key "site_users", "users"
  add_foreign_key "social_media_links", "sites"
  add_foreign_key "user_invitations", "sites"
  add_foreign_key "user_invitations", "users", column: "inviting_user_id"
end
