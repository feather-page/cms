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

ActiveRecord::Schema[8.0].define(version: 2025_04_22_101748) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
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

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "authors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "public_id", limit: 21
    t.string "name"
    t.string "open_library_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["open_library_id"], name: "index_authors_on_open_library_id", unique: true
    t.index ["public_id"], name: "index_authors_on_public_id", unique: true
  end

  create_table "books", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "public_id", limit: 21
    t.string "title"
    t.uuid "author_id", null: false
    t.string "open_library_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_books_on_author_id"
    t.index ["open_library_id"], name: "index_books_on_open_library_id", unique: true
    t.index ["public_id"], name: "index_books_on_public_id", unique: true
  end

  create_table "bookshelf_books", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "book_id", null: false
    t.uuid "bookshelf_id", null: false
    t.string "public_id", limit: 21
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id", "bookshelf_id"], name: "index_bookshelf_books_on_book_id_and_bookshelf_id"
    t.index ["book_id"], name: "index_bookshelf_books_on_book_id"
    t.index ["bookshelf_id", "book_id"], name: "index_bookshelf_books_on_bookshelf_id_and_book_id"
    t.index ["bookshelf_id"], name: "index_bookshelf_books_on_bookshelf_id"
  end

  create_table "bookshelves", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "public_id", limit: 21
    t.uuid "site_id", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "site_id"], name: "index_bookshelves_on_name_and_site_id", unique: true
    t.index ["public_id"], name: "index_bookshelves_on_public_id", unique: true
    t.index ["site_id"], name: "index_bookshelves_on_site_id"
  end

  create_table "deployment_targets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "site_id", null: false
    t.integer "type", null: false
    t.string "public_hostname", null: false
    t.string "provider", null: false
    t.text "encrypted_config"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "public_id", limit: 21, null: false
    t.index ["provider"], name: "index_deployment_targets_on_provider"
    t.index ["public_hostname"], name: "index_deployment_targets_on_public_hostname", unique: true
    t.index ["public_id"], name: "index_deployment_targets_on_public_id", unique: true
    t.index ["site_id"], name: "index_deployment_targets_on_site_id"
    t.index ["type"], name: "index_deployment_targets_on_type"
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.jsonb "serialized_properties"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_discard"
    t.text "callback_queue_name"
    t.integer "callback_priority"
    t.datetime "enqueued_at"
    t.datetime "discarded_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id", null: false
    t.text "job_class"
    t.text "queue_name"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.text "error"
    t.integer "error_event", limit: 2
    t.text "error_backtrace", array: true
    t.uuid "process_id"
    t.interval "duration"
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "state"
    t.integer "lock_type", limit: 2
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "key"
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "queue_name"
    t.integer "priority"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "performed_at"
    t.datetime "finished_at"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id"
    t.text "concurrency_key"
    t.text "cron_key"
    t.uuid "retried_good_job_id"
    t.datetime "cron_at"
    t.uuid "batch_id"
    t.uuid "batch_callback_id"
    t.boolean "is_discrete"
    t.integer "executions_count"
    t.text "job_class"
    t.integer "error_event", limit: 2
    t.text "labels", array: true
    t.uuid "locked_by_id"
    t.datetime "locked_at"
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
    t.integer "state"
    t.string "source_url"
    t.uuid "site_id", null: false
    t.string "imageable_type"
    t.uuid "imageable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "public_id", limit: 21, null: false
    t.index ["imageable_type", "imageable_id"], name: "index_images_on_imageable"
    t.index ["public_id"], name: "index_images_on_public_id", unique: true
    t.index ["site_id"], name: "index_images_on_site_id"
  end

  create_table "navigation_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "public_id"
    t.uuid "navigation_id", null: false
    t.uuid "page_id", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["navigation_id", "position"], name: "index_navigation_items_on_navigation_id_and_position", unique: true
    t.index ["navigation_id"], name: "index_navigation_items_on_navigation_id"
    t.index ["page_id"], name: "index_navigation_items_on_page_id"
    t.index ["public_id"], name: "index_navigation_items_on_public_id", unique: true
  end

  create_table "navigations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "public_id", limit: 21
    t.uuid "site_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_navigations_on_public_id", unique: true
    t.index ["site_id"], name: "index_navigations_on_site_id"
  end

  create_table "pages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.string "emoji"
    t.json "content"
    t.uuid "site_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "public_id", limit: 21, null: false
    t.index ["public_id"], name: "index_pages_on_public_id", unique: true
    t.index ["site_id"], name: "index_pages_on_site_id"
    t.index ["slug", "site_id"], name: "index_pages_on_slug_and_site_id", unique: true
  end

  create_table "posts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.string "emoji"
    t.json "content"
    t.uuid "site_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "public_id", limit: 21, null: false
    t.datetime "publish_at"
    t.boolean "draft", default: false, null: false
    t.index ["draft"], name: "index_posts_on_draft"
    t.index ["public_id"], name: "index_posts_on_public_id", unique: true
    t.index ["publish_at"], name: "index_posts_on_publish_at"
    t.index ["site_id"], name: "index_posts_on_site_id"
    t.index ["slug", "site_id"], name: "index_posts_on_slug_and_site_id", unique: true
  end

  create_table "site_users", force: :cascade do |t|
    t.string "role", default: "editor", null: false
    t.uuid "site_id", null: false
    t.uuid "user_id", null: false
    t.string "public_id", limit: 21, null: false
    t.index ["public_id"], name: "index_site_users_on_public_id", unique: true
    t.index ["role"], name: "index_site_users_on_role"
    t.index ["site_id"], name: "index_site_users_on_site_id"
    t.index ["user_id", "site_id"], name: "index_site_users_on_user_id_and_site_id", unique: true
    t.index ["user_id"], name: "index_site_users_on_user_id"
  end

  create_table "sites", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "domain"
    t.string "title"
    t.string "language_code", default: "en", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "public_id", limit: 21, null: false
    t.uuid "theme_id", null: false
    t.string "emoji", limit: 4, default: "🌐"
    t.string "copyright", default: "© All rights reserved."
    t.index ["domain"], name: "index_sites_on_domain", unique: true
    t.index ["public_id"], name: "index_sites_on_public_id", unique: true
    t.index ["theme_id"], name: "index_sites_on_theme_id"
  end

  create_table "social_media_links", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "public_id", limit: 21
    t.string "name"
    t.string "icon"
    t.string "url"
    t.uuid "site_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_social_media_links_on_public_id", unique: true
    t.index ["site_id"], name: "index_social_media_links_on_site_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.binary "payload", null: false
    t.datetime "created_at", null: false
    t.bigint "channel_hash", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "themes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "public_id", limit: 21, null: false
    t.string "description"
    t.string "hugo_theme", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_themes_on_public_id", unique: true
  end

  create_table "user_invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email"
    t.string "public_id"
    t.datetime "accepted_at", precision: nil
    t.uuid "site_id", null: false
    t.uuid "inviting_user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accepted_at"], name: "index_user_invitations_on_accepted_at"
    t.index ["email", "site_id"], name: "index_user_invitations_on_email_and_site_id", unique: true
    t.index ["inviting_user_id"], name: "index_user_invitations_on_inviting_user_id"
    t.index ["public_id"], name: "index_user_invitations_on_public_id", unique: true
    t.index ["site_id"], name: "index_user_invitations_on_site_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", null: false
    t.datetime "last_login_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "super_admin", default: false, null: false
    t.string "public_id", limit: 21, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["public_id"], name: "index_users_on_public_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "books", "authors"
  add_foreign_key "bookshelf_books", "books"
  add_foreign_key "bookshelf_books", "bookshelves"
  add_foreign_key "bookshelves", "sites"
  add_foreign_key "deployment_targets", "sites"
  add_foreign_key "images", "sites"
  add_foreign_key "navigation_items", "navigations"
  add_foreign_key "navigation_items", "pages"
  add_foreign_key "navigations", "sites"
  add_foreign_key "pages", "sites"
  add_foreign_key "posts", "sites"
  add_foreign_key "site_users", "sites"
  add_foreign_key "site_users", "users"
  add_foreign_key "sites", "themes"
  add_foreign_key "social_media_links", "sites"
  add_foreign_key "user_invitations", "sites"
  add_foreign_key "user_invitations", "users", column: "inviting_user_id"
end
