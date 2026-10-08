defmodule Feather.Repo.Migrations.CreateContentTables do
  use Ecto.Migration

  # Every table is created in one statement: SQLite cannot add a NOT NULL
  # column without a default through ALTER TABLE. SQLite only checks that a
  # referenced table exists when rows are written, so posts can reference
  # images before the images table exists and vice versa.
  def change do
    create table(:api_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string
      add :token_digest, :string, null: false
      add :token_prefix, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:api_tokens, [:user_id])
    create unique_index(:api_tokens, [:token_digest])

    create table(:sites, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :public_id, :string, null: false
      add :title, :string, null: false
      add :domain, :string, null: false
      add :language_code, :string, null: false, default: "en"
      add :emoji, :string, default: "🌐"
      add :copyright, :string, null: false, default: "© All rights reserved."

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:sites, [:public_id])
    create unique_index(:sites, [:domain])

    create table(:site_users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "editor"

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:site_users, [:user_id, :site_id])
    create index(:site_users, [:site_id])

    create table(:invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false

      add :inviting_user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false

      add :email, :string, null: false, collate: :nocase
      add :accepted_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:invitations, [:email, :site_id])
    create index(:invitations, [:site_id])

    create table(:social_media_links, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :url, :string, null: false
      add :icon, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:social_media_links, [:site_id])

    create table(:posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :public_id, :string, null: false
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :title, :string
      add :slug, :string
      add :emoji, :string
      add :tags, :string
      add :content, :map
      add :draft, :boolean, null: false, default: false
      add :publish_at, :utc_datetime_usec
      add :header_image_id, references(:images, type: :binary_id, on_delete: :nilify_all)
      add :thumbnail_image_id, references(:images, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:posts, [:public_id])
    create unique_index(:posts, [:site_id, :slug])
    create index(:posts, [:site_id, :publish_at])

    create table(:pages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :public_id, :string, null: false
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :title, :string
      add :slug, :string, null: false
      add :emoji, :string
      add :tags, :string
      add :content, :map
      add :page_type, :string, null: false, default: "default"
      add :header_image_id, references(:images, type: :binary_id, on_delete: :nilify_all)
      add :thumbnail_image_id, references(:images, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:pages, [:public_id])
    create unique_index(:pages, [:site_id, :slug])

    create table(:projects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :public_id, :string, null: false
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :slug, :string, null: false
      add :emoji, :string
      add :tags, :string
      add :content, :map
      add :short_description, :text, null: false
      add :company, :string
      add :role, :string
      add :period, :string
      add :started_at, :date, null: false
      add :ended_at, :date
      add :status, :string, null: false, default: "ongoing"
      add :project_type, :string, null: false, default: "professional"
      add :links, :map
      add :header_image_id, references(:images, type: :binary_id, on_delete: :nilify_all)
      add :thumbnail_image_id, references(:images, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:projects, [:public_id])
    create unique_index(:projects, [:site_id, :slug])
    create index(:projects, [:site_id, :started_at])

    # post_id, page_id and project_id record which post, page or project embeds
    # the image in its content. Header, thumbnail and cover images are
    # referenced by their owner instead.
    create table(:images, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :public_id, :string, null: false
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :post_id, references(:posts, type: :binary_id, on_delete: :nilify_all)
      add :page_id, references(:pages, type: :binary_id, on_delete: :nilify_all)
      add :project_id, references(:projects, type: :binary_id, on_delete: :nilify_all)
      add :filename, :string, null: false
      add :content_type, :string, null: false
      add :byte_size, :integer, null: false
      add :width, :integer
      add :height, :integer
      add :source_url, :string
      add :unsplash_data, :map

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:images, [:public_id])
    create index(:images, [:site_id])
    create index(:images, [:post_id])
    create index(:images, [:page_id])
    create index(:images, [:project_id])

    create table(:navigation_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :page_id, references(:pages, type: :binary_id, on_delete: :delete_all), null: false
      add :position, :integer, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:navigation_items, [:site_id, :page_id])
    create index(:navigation_items, [:site_id, :position])

    create table(:books, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :public_id, :string, null: false
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :post_id, references(:posts, type: :binary_id, on_delete: :nilify_all)
      add :cover_image_id, references(:images, type: :binary_id, on_delete: :nilify_all)
      add :title, :string, null: false
      add :author, :string, null: false
      add :emoji, :string
      add :isbn, :string
      add :open_library_key, :string
      add :rating, :integer
      add :read_at, :date
      add :reading_status, :string, null: false, default: "finished"

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:books, [:public_id])
    create index(:books, [:site_id, :reading_status])
    create unique_index(:books, [:post_id])

    create table(:deployment_targets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :public_id, :string, null: false
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :provider, :string, null: false
      add :public_hostname, :string, null: false
      add :config, :binary
      add :deploying, :boolean, null: false, default: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:deployment_targets, [:public_id])
    create unique_index(:deployment_targets, [:public_hostname])
    create index(:deployment_targets, [:site_id])
  end
end
