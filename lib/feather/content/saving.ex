defmodule Feather.Content.Saving do
  @moduledoc """
  Saving, publishing and deleting posts, pages and projects with the
  images they own (see "Saving" in `Feather.Content`), called through
  `Feather.Content`.
  """

  import Feather.Content.Versions, only: [lock: 1, touch_site_if: 2]

  alias Feather.Accounts.Scope
  alias Feather.Content.{Blocks, Page, Post, Project, Suggestions, Versions}
  alias Feather.Media
  alias Feather.Media.Cleanup
  alias Feather.Repo
  alias Feather.Sites.Site

  @lock_opts Versions.lock_opts()
  @versions Versions.versions()

  @doc """
  Publishes a post, page or project: turns its current state into a new
  version, published by the scope's user, and makes it the published
  version. The record's `updated_at` stays. A published record without
  unpublished changes stays as it is.

  It acts on the record as stored, which must still have the
  `lock_version` of the given one: a record changed elsewhere since
  returns `{:error, :stale}` and publishes nothing, so nobody publishes a
  state they have not seen.

  Fails with `{:error, :slug_taken}` when another record of its URL space
  (`Feather.Content.Slug.url_space/1`, posts and pages share one) is
  published with the record's slug: the unique slug of the current
  records does not cover a published version whose record has moved on.

  Publishing a record under a URL other than the one it was last
  published at redirects the old URL to it (`Feather.Redirects.follow_publish/3`).

  Before a post or page is published, the model writes its description
  where `Feather.Content.Description.needed?/2` says so, and a short
  post's meta title and slug where `Feather.Content.ShortPost.needed?/2`
  does, outside the transaction, since that can take up to 90 seconds.
  Without an answer it is published as it is.
  """
  @spec publish(Scope.t(), record) :: {:ok, record} | {:error, :stale | :slug_taken}
        when record: Post.t() | Page.t() | Project.t()
  def publish(%Scope{site: %Site{id: site_id}} = scope, %schema{site_id: site_id} = record)
      when is_map_key(@versions, schema) do
    suggestions =
      case Versions.stored(record) do
        {:ok, current} -> Suggestions.publish_suggestions(scope, current)
        {:error, :stale} -> %{}
      end

    Repo.transact(fn ->
      Versions.publish_stored(scope, record,
        prepare: &Suggestions.put_suggestions(&1, suggestions)
      )
    end)
  end

  @doc false
  def save_with_images(%Ecto.Changeset{} = changeset, owner_field) do
    changeset =
      changeset
      |> Media.validate_site_images([:header_image_id, :thumbnail_image_id])
      |> lock()

    Repo.transact(fn ->
      with {:ok, record} <- Repo.insert_or_update(changeset, @lock_opts) do
        Media.assign_images(
          record.site_id,
          owner_field,
          record.id,
          Blocks.image_ids(record.content)
        )

        {:ok, record}
      end
    end)
  end

  @doc false
  def delete_with_images(scope, record, owner_field) do
    images = Media.list_images_owned_by(owner_field, record.id)

    result =
      Repo.transact(fn ->
        published? = Versions.stored_published?(record)

        with {:ok, record} <- Repo.delete(record),
             :ok <- touch_site_if(published?, scope) do
          {:ok, {record, Cleanup.delete_released(images)}}
        end
      end)

    with {:ok, {record, deleted}} <- result do
      Enum.each(deleted, &Media.delete_image_files/1)
      {:ok, record}
    end
  end
end
