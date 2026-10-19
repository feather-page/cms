defmodule Feather.StaticSite.ImageVariants do
  @moduledoc """
  Which variants (`Feather.Media.Variants`) an image of a site needs: the
  union over its roles of the sizes the site's theme declares for each
  role (`c:Feather.StaticSite.Theme.image_variants/0`), plus the 1200 px
  JPEG for the sharing image. Every image also keeps the admin preview.

  An image's roles follow from what references it, in the records as they
  are and as their published versions show them, so a draft's images are
  ready before it is published:

    * `:content` - an image block of a post, page or project
    * `:header`, `:thumbnail` - a post's or page's header, a post's thumbnail
    * `:homepage_header` - the homepage's header
    * `:project_header`, `:project_thumbnail` - a project's header and thumbnail
    * `:book_cover` - a book's cover
    * `:portrait`, `:footer_mascot`, `:post_end_mascot`, `:projects_mascot` - the site's
    * `:sharing` - the `og:image` of a post, page or project: its header,
      else its thumbnail, else its first content image

  `sync_site/1` brings the stored variants in line; it runs for every site
  on start (`backfill/0`) and for a site whose theme changes.
  """

  import Ecto.Query, warn: false

  alias Feather.Accounts.Scope
  alias Feather.{Books, Content, Media, Repo}
  alias Feather.Content.Blocks
  alias Feather.Content.{Page, Post, Project}
  alias Feather.Media.{Image, Variants}
  alias Feather.Sites.Site
  alias Feather.StaticSite.Themes

  require Logger

  @type role ::
          :content
          | :header
          | :thumbnail
          | :homepage_header
          | :project_header
          | :project_thumbnail
          | :book_cover
          | :portrait
          | :footer_mascot
          | :post_end_mascot
          | :projects_mascot
          | :sharing

  @site_roles [
    portrait_image_id: :portrait,
    footer_mascot_image_id: :footer_mascot,
    post_end_mascot_image_id: :post_end_mascot,
    projects_mascot_image_id: :projects_mascot
  ]

  @doc "The sizes the site's theme declares for a role, smallest first."
  @spec sizes(Site.t(), role()) :: [pos_integer()]
  def sizes(%Site{} = site, role), do: Map.get(Themes.module(site).image_variants(), role, [])

  @doc """
  The variants an upload for a role gets (its size is not known yet; see
  `Feather.Media.create_image_from_upload/5`).
  """
  @spec for_role(Site.t(), role()) :: [Variants.variant()]
  def for_role(%Site{}, :sharing), do: [Variants.sharing()]
  def for_role(%Site{} = site, role), do: site |> sizes(role) |> Enum.map(&Variants.webp/1)

  @doc "The variants an upload for a site image field (`:portrait_image_id`, a mascot) gets."
  @spec for_site_field(Site.t(), atom()) :: [Variants.variant()]
  def for_site_field(%Site{} = site, field),
    do: for_role(site, Keyword.fetch!(@site_roles, field))

  @doc """
  The variants an image with the given roles needs in the site's theme:
  per role the webp variants of its sizes (collapsed where the image is too
  small, as `Feather.Media.Variants.for_image/3` does), then the JPEG of
  the sharing image.
  """
  @spec variants(Site.t(), Image.t(), [role()]) :: [Variants.variant()]
  def variants(%Site{} = site, %Image{width: width, height: height}, roles) do
    webp = Enum.flat_map(roles, &Variants.for_image(sizes(site, &1), width, height))
    jpg = if :sharing in roles, do: [Variants.sharing()], else: []
    Enum.uniq(webp ++ jpg)
  end

  @doc "The variants one image of the site needs (see `variants/3`)."
  @spec variants_of(Site.t(), Image.t()) :: [Variants.variant()]
  def variants_of(%Site{} = site, %Image{id: id} = image),
    do: variants(site, image, Map.get(image_roles(site), id, []))

  @doc "The roles of the site's images by image id, sorted; unreferenced images are missing."
  @spec image_roles(Site.t()) :: %{Ecto.UUID.t() => [role()]}
  def image_roles(%Site{} = site) do
    scope = Scope.for_site(site)
    ids_by_public_id = Map.new(Media.list_images(scope), &{&1.public_id, &1.id})

    group_roles(
      record_references(scope, ids_by_public_id) ++
        book_references(scope) ++ site_references(site)
    )
  end

  defp group_roles(references) do
    references
    |> Enum.reject(fn {id, _role} -> is_nil(id) end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {id, roles} -> {id, roles |> Enum.uniq() |> Enum.sort()} end)
  end

  defp record_references(scope, ids_by_public_id) do
    records =
      for list <- [
            Content.list_posts(scope),
            Content.list_pages(scope),
            Content.list_projects(scope)
          ],
          record <- list ++ Content.as_published(list),
          do: record

    Enum.flat_map(records, &references(&1, ids_by_public_id))
  end

  defp references(record, ids_by_public_id) do
    content_ids =
      record.content |> Blocks.image_ids() |> Enum.map(&Map.get(ids_by_public_id, &1))

    {header_role, thumbnail_role} = picture_roles(record)
    thumbnail_id = if thumbnail_role, do: record.thumbnail_image_id
    sharing_id = record.header_image_id || thumbnail_id || Enum.find(content_ids, & &1)

    [
      {record.header_image_id, header_role},
      {thumbnail_id, thumbnail_role},
      {sharing_id, :sharing}
      | Enum.map(content_ids, &{&1, :content})
    ]
  end

  defp picture_roles(%Post{}), do: {:header, :thumbnail}
  defp picture_roles(%Project{}), do: {:project_header, :project_thumbnail}

  defp picture_roles(%Page{} = page),
    do: {if(Page.homepage?(page), do: :homepage_header, else: :header), nil}

  defp book_references(scope),
    do: for(book <- Books.list_books(scope), do: {book.cover_image_id, :book_cover})

  defp site_references(site),
    do: for({field, role} <- @site_roles, do: {Map.get(site, field), role})

  @doc """
  Brings the stored variants of every image of the site in line with its
  roles (`Feather.Media.sync_variants/2`). Images whose original is missing
  are logged and skipped.
  """
  @spec sync_site(Site.t()) :: :ok
  def sync_site(%Site{} = site) do
    roles = image_roles(site)

    for image <- Media.list_images(Scope.for_site(site)) do
      variants = variants(site, image, Map.get(roles, image.id, []))

      case Media.sync_variants(image, variants) do
        {:ok, _changes} ->
          :ok

        {:error, reason} ->
          Logger.warning("Image #{image.public_id} could not be synced: #{inspect(reason)}")
      end
    end

    :ok
  end

  @doc """
  Runs `sync_site/1` under `Feather.TaskSupervisor`, or right away with
  `config :feather, :image_variant_sync, :inline` (as in tests).
  """
  @spec start_sync(Site.t()) :: :ok
  def start_sync(%Site{} = site) do
    case Application.get_env(:feather, :image_variant_sync, :background) do
      :inline ->
        sync_site(site)

      :background ->
        Feather.TaskSupervisor
        |> Task.Supervisor.start_child(fn -> sync_site(site) end)
        |> log_start_failure(site)
    end
  end

  defp log_start_failure({:ok, _pid}, _site), do: :ok

  defp log_start_failure({:error, reason}, site) do
    Logger.error("Image variants of site #{site.public_id} not synced: #{inspect(reason)}")
  end

  @doc "Runs `sync_site/1` for every site; a site that fails is logged and skipped."
  @spec backfill() :: :ok
  def backfill do
    Site |> Repo.all() |> Enum.each(&sync_site_safely/1)
  end

  defp sync_site_safely(site) do
    sync_site(site)
  rescue
    exception ->
      Logger.error(
        "Image variants of site #{site.public_id} could not be synced: " <>
          Exception.message(exception)
      )
  end
end
