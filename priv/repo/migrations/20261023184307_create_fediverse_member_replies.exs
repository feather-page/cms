defmodule Feather.Repo.Migrations.CreateFediverseMemberReplies do
  use Ecto.Migration

  def change do
    alter table(:fediverse_mentions) do
      add :named_accounts, {:array, :string}, null: false, default: "[]"
    end

    create table(:fediverse_member_replies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :public_id, :string, null: false
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false

      add :mention_id,
          references(:fediverse_mentions, type: :binary_id, on_delete: :nilify_all)

      add :post_id, references(:posts, type: :binary_id, on_delete: :nilify_all)
      add :in_reply_to, :string, null: false
      add :visibility, :string, null: false
      add :content, :binary, null: false
      add :recipients, {:array, :string}, null: false, default: "[]"
      add :deleted_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:fediverse_member_replies, [:public_id])
    create index(:fediverse_member_replies, [:site_id])
    create index(:fediverse_member_replies, [:mention_id])
    create index(:fediverse_member_replies, [:post_id])
  end
end
