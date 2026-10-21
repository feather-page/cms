defmodule Feather.Content.Backfill do
  @moduledoc """
  Fills in the model's suggestions (`Feather.Content.Suggestions`) for
  content published before they existed, called through `Feather.Content`.
  """

  import Ecto.Query, warn: false

  alias Feather.Accounts.Scope
  alias Feather.Content.{Description, Page, Post, ShortPost, Suggestions, Versions}
  alias Feather.Repo
  alias Feather.Sites.Site

  @doc """
  Fills in what the model would have suggested at publish for the scope's
  published posts and pages without unpublished changes, content
  published before the suggestions existed: a missing description, and a
  short post's missing meta title or slug.
  Each record that gets a suggestion is published again, which redirects
  its old URL to a new one (`Feather.Content.publish/2`); records with
  unpublished changes are skipped, so nothing unseen goes out. Returns the
  records published again.
  """
  @spec backfill_suggestions(Scope.t()) :: [Post.t() | Page.t()]
  def backfill_suggestions(%Scope{site: %Site{id: site_id}} = scope) do
    for schema <- [Post, Page],
        record <-
          Repo.all(
            from r in schema,
              where: r.site_id == ^site_id and not is_nil(r.published_version_id),
              order_by: r.inserted_at,
              preload: :published_version
          ),
        Versions.publication_status(record) == :published,
        {:ok, published} <- [backfill_record(scope, record)],
        do: published
  end

  defp backfill_record(scope, record) do
    suggestions =
      Suggestions.ask_model(scope, record,
        description?: Description.needed?(record, record.published_version),
        short_post?: ShortPost.backfill?(record)
      )

    if suggestions == %{} do
      :unchanged
    else
      Repo.transact(fn ->
        Versions.publish_stored(scope, record,
          state: :published,
          prepare: &Suggestions.put_suggestions(&1, suggestions)
        )
      end)
    end
  end
end
