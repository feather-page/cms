defmodule Feather.Repo.Migrations.AddEmbeddingToPostVersions do
  use Ecto.Migration

  def change do
    alter table(:post_versions) do
      add :embedding, :binary
      add :embedding_model, :string
    end
  end
end
