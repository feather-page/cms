defmodule Feather.Media.Cleanup do
  @moduledoc """
  Finds and deletes images nothing uses any more. Two kinds:

    * **unreferenced** - no post, page or project owns it, it is not the
      header or thumbnail image of any post, page or project, not the cover
      of a book and no image block of its site embeds it
    * **unused** - a post, page or project owns it, but no image block in
      the owner's content embeds it any more (and it is not a header,
      thumbnail or cover image either)

  Images younger than the grace period (2 days) are never touched, so an
  upload whose post has not been saved yet survives.

  This is the intent of Rails' `CleanupOrphanedImagesJob`, which deleted
  header images (they have no owner) and failed on book covers.
  """

  import Ecto.Query, warn: false

  alias Feather.Repo
  alias Feather.Books.Book
  alias Feather.Content.{Blocks, Page, Post, Project}
  alias Feather.Media
  alias Feather.Media.Image

  @grace_period_days 2
  @owners [post_id: Post, page_id: Page, project_id: Project]

  @type result :: %{unreferenced: [Image.t()], unused: [Image.t()]}

  @doc "Images younger than this many days are never deleted."
  @spec grace_period_days() :: pos_integer()
  def grace_period_days, do: @grace_period_days

  @doc """
  Lists the images `delete_orphaned/1` would delete at `now`, without
  deleting anything.
  """
  @spec orphaned(DateTime.t()) :: result()
  def orphaned(%DateTime{} = now) do
    cutoff = DateTime.add(now, -@grace_period_days, :day)

    candidates =
      Repo.all(from i in Image, where: i.inserted_at < ^cutoff, order_by: i.inserted_at)

    if candidates == [] do
      %{unreferenced: [], unused: []}
    else
      featured = featured_image_ids()
      {unowned, owned} = Enum.split_with(candidates, &(owner(&1) == nil))
      unowned = Enum.reject(unowned, &MapSet.member?(featured, &1.id))
      owned = Enum.reject(owned, &MapSet.member?(featured, &1.id))

      %{unreferenced: unreferenced(unowned), unused: unused(owned)}
    end
  end

  @doc """
  Deletes the orphaned images (rows and files) and returns them. The rows
  are deleted in one transaction, the files after it committed.
  """
  @spec delete_orphaned(DateTime.t()) :: {:ok, result()} | {:error, term()}
  def delete_orphaned(%DateTime{} = now) do
    result =
      Repo.transact(fn ->
        %{unreferenced: unreferenced, unused: unused} = orphaned = orphaned(now)
        ids = Enum.map(unreferenced ++ unused, & &1.id)
        Repo.delete_all(from i in Image, where: i.id in ^ids)
        {:ok, orphaned}
      end)

    with {:ok, %{unreferenced: unreferenced, unused: unused}} <- result do
      Enum.each(unreferenced ++ unused, &Media.delete_image_files/1)
      result
    end
  end

  # Header, thumbnail and cover images.
  defp featured_image_ids do
    queries =
      for {_field, schema} <- @owners, field <- [:header_image_id, :thumbnail_image_id] do
        from r in schema, where: not is_nil(field(r, ^field)), select: field(r, ^field)
      end

    covers = from b in Book, where: not is_nil(b.cover_image_id), select: b.cover_image_id

    (queries ++ [covers])
    |> Enum.flat_map(&Repo.all/1)
    |> MapSet.new()
  end

  defp owner(%Image{} = image) do
    Enum.find_value(@owners, fn {field, schema} ->
      if id = Map.fetch!(image, field), do: {field, schema, id}
    end)
  end

  # Unowned images are still kept when an image block of their site embeds
  # them (content saved before ownership was recorded).
  defp unreferenced([]), do: []

  defp unreferenced(images) do
    site_ids = images |> Enum.map(& &1.site_id) |> Enum.uniq()

    embedded =
      for {_field, schema} <- @owners,
          {site_id, content} <-
            Repo.all(
              from r in schema, where: r.site_id in ^site_ids, select: {r.site_id, r.content}
            ),
          public_id <- Blocks.image_ids(content),
          into: MapSet.new(),
          do: {site_id, public_id}

    Enum.reject(images, &MapSet.member?(embedded, {&1.site_id, &1.public_id}))
  end

  defp unused([]), do: []

  defp unused(images) do
    embedded =
      images
      |> Enum.map(&owner/1)
      |> Enum.group_by(fn {_field, schema, _id} -> schema end, fn {_, _, id} -> id end)
      |> Enum.flat_map(fn {schema, ids} ->
        Repo.all(from r in schema, where: r.id in ^Enum.uniq(ids), select: {r.id, r.content})
      end)
      |> Map.new(fn {id, content} -> {id, MapSet.new(Blocks.image_ids(content))} end)

    Enum.reject(images, fn image ->
      {_field, _schema, owner_id} = owner(image)
      embedded |> Map.get(owner_id, MapSet.new()) |> MapSet.member?(image.public_id)
    end)
  end
end
