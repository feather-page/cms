defmodule Feather.Content.Pages do
  @moduledoc """
  The pages of a site, called through `Feather.Content`. Pages come with
  `add_to_navigation` filled in: whether the main navigation links them.
  """

  import Ecto.Query, warn: false
  import Feather.Content.Versions, only: [put_navigation_flag: 1]

  alias Feather.Accounts.Scope
  alias Feather.Content.{Page, Saving, Slug}
  alias Feather.Pagination
  alias Feather.Repo
  alias Feather.Sites
  alias Feather.Sites.Site

  @doc """
  Lists the pages of the scope's site, the homepage first, then by title.
  `add_to_navigation` is filled in.
  """
  @spec list_pages(Scope.t()) :: [Page.t()]
  def list_pages(%Scope{site: %Site{id: site_id}}) do
    from(p in Page,
      where: p.site_id == ^site_id,
      order_by: [desc: p.slug == "/", asc: p.title, asc: p.inserted_at]
    )
    |> Repo.all()
    |> put_navigation_flags()
  end

  @doc """
  Gets a page of the scope's site by public id, with `add_to_navigation`
  filled in. Raises if not found.
  """
  @spec get_page!(Scope.t(), String.t()) :: Page.t()
  def get_page!(%Scope{site: %Site{id: site_id}}, public_id) do
    from(p in Page, where: p.site_id == ^site_id and p.public_id == ^public_id)
    |> Repo.one!()
    |> put_navigation_flag()
  end

  @doc """
  Gets a page of the scope's site by public id, with `add_to_navigation`
  filled in, or nil.
  """
  @spec get_page(Scope.t(), String.t()) :: Page.t() | nil
  def get_page(%Scope{site: %Site{id: site_id}}, public_id) do
    case Repo.one(from p in Page, where: p.site_id == ^site_id and p.public_id == ^public_id) do
      nil -> nil
      page -> put_navigation_flag(page)
    end
  end

  @doc """
  One page of the scope's pages (the homepage first, then by title), with
  header and thumbnail images preloaded and `add_to_navigation` filled in.
  Pages beyond the last one are empty (the content API).
  """
  @spec paginate_pages(Scope.t(), pos_integer() | String.t() | nil) :: Pagination.t()
  def paginate_pages(%Scope{site: %Site{id: site_id}}, page) do
    from(p in Page,
      where: p.site_id == ^site_id,
      order_by: [desc: p.slug == "/", asc: p.title, asc: p.inserted_at, asc: p.id],
      preload: [:header_image, :thumbnail_image]
    )
    |> Pagination.paginate(page, out_of_range: :empty)
    |> Map.update!(:entries, &put_navigation_flags/1)
  end

  @doc """
  One page of the scope's pages that are not in the main navigation, the
  homepage first, then by title, with the thumbnail image and the published
  version preloaded.
  """
  @spec paginate_pages_outside_navigation(Scope.t(), pos_integer() | String.t() | nil) ::
          Pagination.t()
  def paginate_pages_outside_navigation(%Scope{site: %Site{id: site_id}}, page) do
    query =
      from p in Page,
        left_join: n in Feather.Sites.NavigationItem,
        on: n.page_id == p.id,
        where: p.site_id == ^site_id and is_nil(n.id),
        order_by: [desc: p.slug == "/", asc: p.title, asc: p.inserted_at],
        preload: [:thumbnail_image, :published_version]

    Pagination.paginate(query, page)
  end

  @doc """
  Gets a page of the scope's site by slug, or nil.
  """
  @spec get_page_by_slug(Scope.t(), String.t()) :: Page.t() | nil
  def get_page_by_slug(%Scope{site: %Site{id: site_id}}, slug) do
    case Repo.get_by(Page, site_id: site_id, slug: Slug.normalize(slug)) do
      nil -> nil
      page -> put_navigation_flag(page)
    end
  end

  @doc "The homepage of the scope's site, or nil."
  @spec get_homepage(Scope.t()) :: Page.t() | nil
  def get_homepage(%Scope{} = scope), do: get_page_by_slug(scope, "/")

  @doc """
  Creates a page in the scope's site, as a draft unless `draft: false` is
  given (see "Saving" in the `Feather.Content` module doc). With
  `add_to_navigation: true` the page is appended to the main navigation.
  """
  @spec create_page(Scope.t(), map(), keyword()) ::
          {:ok, Page.t()} | {:error, Ecto.Changeset.t()}
  def create_page(%Scope{site: %Site{id: site_id}} = scope, attrs, opts \\ []) do
    %Page{site_id: site_id}
    |> Page.create_changeset(attrs)
    |> save_page(scope, opts)
  end

  @doc """
  Updates a page: stores the changes as its unpublished changes (`draft:`,
  see "Saving" in the `Feather.Content` module doc). When
  `add_to_navigation` is given, the page is added to or removed from the
  main navigation accordingly.
  """
  @spec update_page(Scope.t(), Page.t(), map(), keyword()) ::
          {:ok, Page.t()} | {:error, Ecto.Changeset.t()}
  def update_page(
        %Scope{site: %Site{id: site_id}} = scope,
        %Page{site_id: site_id} = page,
        attrs,
        opts \\ []
      ) do
    page
    |> Page.changeset(attrs)
    |> save_page(scope, opts)
  end

  defp save_page(changeset, scope, opts) do
    navigation_given? = Map.has_key?(changeset.params || %{}, "add_to_navigation")

    Repo.transact(fn ->
      with {:ok, page} <- Saving.save_with_images(changeset, scope, :page_id, opts) do
        sync_navigation(navigation_given?, scope, page)
        {:ok, put_navigation_flag(page)}
      end
    end)
  end

  defp sync_navigation(false, _scope, _page), do: :ok

  defp sync_navigation(true, scope, %Page{add_to_navigation: true} = page) do
    {:ok, _item} = Sites.add_to_navigation(scope, page)
  end

  defp sync_navigation(true, scope, %Page{} = page) do
    :ok = Sites.remove_from_navigation(scope, page)
  end

  @doc """
  Deletes a page (and its navigation item) and the images it owns that nothing else uses.
  """
  @spec delete_page(Scope.t(), Page.t()) :: {:ok, Page.t()} | {:error, Ecto.Changeset.t()}
  def delete_page(%Scope{site: %Site{id: site_id}} = scope, %Page{site_id: site_id} = page) do
    Repo.transact(fn ->
      :ok = Sites.remove_from_navigation(scope, page)
      Saving.delete_with_images(scope, page, :page_id)
    end)
  end

  @doc "Returns a changeset for a page form."
  @spec change_page(Scope.t(), Page.t(), map()) :: Ecto.Changeset.t()
  def change_page(%Scope{}, %Page{} = page, attrs \\ %{}) do
    Page.changeset(page, attrs)
  end

  defp put_navigation_flags(pages) do
    ids = Enum.map(pages, & &1.id)

    query = from n in Feather.Sites.NavigationItem, where: n.page_id in ^ids, select: n.page_id
    in_navigation = MapSet.new(Repo.all(query))

    Enum.map(pages, &%{&1 | add_to_navigation: MapSet.member?(in_navigation, &1.id)})
  end
end
