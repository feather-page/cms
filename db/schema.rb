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

ActiveRecord::Schema[8.1].define(version: 2026_01_24_133523) do
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

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
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
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "user_invitations", "sites"
  add_foreign_key "user_invitations", "users", column: "inviting_user_id"
end
