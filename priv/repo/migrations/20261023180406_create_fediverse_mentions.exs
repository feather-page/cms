defmodule Feather.Repo.Migrations.CreateFediverseMentions do
  use Ecto.Migration

  def change do
    alter table(:fediverse_remote_accounts) do
      add :followers_url, :string
    end

    create table(:fediverse_mentions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :public_id, :string, null: false
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false

      add :remote_account_id,
          references(:fediverse_remote_accounts, type: :binary_id, on_delete: :delete_all),
          null: false

      add :post_id, references(:posts, type: :binary_id, on_delete: :nilify_all)
      add :uri, :string, null: false
      add :url, :string
      add :in_reply_to, :string
      add :visibility, :string, null: false
      add :content, :binary
      add :summary, :binary
      add :attachments, :binary, null: false
      add :published_at, :utc_datetime_usec, null: false
      add :read_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:fediverse_mentions, [:public_id])
    create unique_index(:fediverse_mentions, [:site_id, :uri])
    create index(:fediverse_mentions, [:site_id, :published_at])
    create index(:fediverse_mentions, [:remote_account_id])
    create index(:fediverse_mentions, [:post_id])
  end
end
