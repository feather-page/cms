defmodule Feather.Repo.Migrations.CreateFediverseFollowedAccountsAndTimelinePosts do
  use Ecto.Migration

  def change do
    create table(:fediverse_followed_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :public_id, :string, null: false
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false

      add :remote_account_id,
          references(:fediverse_remote_accounts, type: :binary_id, on_delete: :delete_all),
          null: false

      add :follow_id, :string, null: false
      add :accepted_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:fediverse_followed_accounts, [:public_id])
    create unique_index(:fediverse_followed_accounts, [:site_id, :remote_account_id])
    create index(:fediverse_followed_accounts, [:remote_account_id])

    create table(:fediverse_timeline_posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :public_id, :string, null: false
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false

      add :followed_account_id,
          references(:fediverse_followed_accounts, type: :binary_id, on_delete: :delete_all),
          null: false

      add :uri, :string, null: false
      add :url, :string
      add :in_reply_to, :string
      add :visibility, :string, null: false
      add :name, :binary
      add :content, :binary
      add :summary, :binary
      add :attachments, :binary, null: false
      add :named_accounts, {:array, :string}, null: false, default: "[]"
      add :published_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:fediverse_timeline_posts, [:public_id])
    create unique_index(:fediverse_timeline_posts, [:site_id, :uri])
    create index(:fediverse_timeline_posts, [:site_id, :published_at])
    create index(:fediverse_timeline_posts, [:followed_account_id])
    create index(:fediverse_timeline_posts, [:inserted_at])

    alter table(:fediverse_member_replies) do
      add :timeline_post_id,
          references(:fediverse_timeline_posts, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:fediverse_member_replies, [:timeline_post_id])
  end
end
