defmodule Feather.Media.Cleanup do
  @moduledoc """
  Finds and deletes images nothing uses any more. Two kinds:

    * **unreferenced** - no post, page or project owns it, it is not the
      header or thumbnail image of any post, page or project, not the cover
      of a book and no image block of its site embeds it
    * **unused** - a post, page or project owns it, but no image block in
      the owner's content embeds it any more (and it is not a header,
      thumbnail or cover image either)

  Either way an image that an image block of any post, page or project of
  its site embeds is kept: images can be embedded by more than one record
  (copied blocks, content API imports), but only one owns them.
  `delete_released/1` applies the same rule when the owner is deleted.

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
      embedded = embedded_by(candidates)

      {unowned, owned} =
        candidates
        |> Enum.reject(&(MapSet.member?(featured, &1.id) or Map.has_key?(embedded, key(&1))))
        |> Enum.split_with(&(owner(&1) == nil))

      %{unreferenced: unowned, unused: owned}
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

  @doc """
  Handles the images a deleted post, page or project owned (`images`,
  listed before the deletion). Each one that is still used stays: it is
  given to another record of its site that embeds it, if there is one, and
  otherwise (a header, thumbnail or cover image) keeps no owner. The others
  are deleted; their rows here, their files are left to the caller (after
  the transaction commits). Returns the deleted images.
  """
  @spec delete_released([Image.t()]) :: [Image.t()]
  def delete_released([]), do: []

  def delete_released(images) do
    featured = featured_image_ids()
    embedded = embedded_by(images)

    Enum.flat_map(images, fn image ->
      case Map.get(embedded, key(image)) do
        [{owner_field, owner_id} | _] ->
          Media.assign_images(image.site_id, owner_field, owner_id, [image.public_id])
          []

        nil ->
          if MapSet.member?(featured, image.id) do
            Repo.update_all(from(i in Image, where: i.id == ^image.id),
              set: [post_id: nil, page_id: nil, project_id: nil]
            )

            []
          else
            Repo.delete_all(from i in Image, where: i.id == ^image.id)
            [image]
          end
      end
    end)
  end

  defp key(%Image{site_id: site_id, public_id: public_id}), do: {site_id, public_id}

  # {site_id, image public id} => [{owner field, record id}] of every post,
  # page and project of the images' sites whose content embeds the image.
  defp embedded_by(images) do
    site_ids = images |> Enum.map(& &1.site_id) |> Enum.uniq()

    for {field, schema} <- @owners,
        {site_id, id, content} <-
          Repo.all(
            from r in schema,
              where: r.site_id in ^site_ids,
              order_by: r.inserted_at,
              select: {r.site_id, r.id, r.content}
          ),
        public_id <- Blocks.image_ids(content),
        reduce: %{} do
      acc -> Map.update(acc, {site_id, public_id}, [{field, id}], &(&1 ++ [{field, id}]))
    end
  end
end
