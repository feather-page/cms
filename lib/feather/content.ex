defmodule Feather.Content do
  @moduledoc """
  Posts, pages and projects of a site.

  Every function takes a `%Scope{}` whose `site` is set (see
  `Feather.Accounts.Scope.put_site/2`) and only sees that site's records.
  Records are looked up by public id.

  Saving content assigns the images referenced by its image blocks to the
  record (`images.post_id` / `page_id` / `project_id`), like Rails did.
  Deleting a record deletes the images embedded in it.
  """

  import Ecto.Query, warn: false

  alias Feather.Repo
  alias Feather.Accounts.Scope
  alias Feather.Content.{Blocks, Page, Post, Project, Slug, Tags}
  alias Feather.Media
  alias Feather.Sites
  alias Feather.Sites.Site

  ## Posts

  @doc """
  Lists the posts of the scope's site, newest `publish_at` first.
  """
  @spec list_posts(Scope.t()) :: [Post.t()]
  def list_posts(%Scope{site: %Site{id: site_id}}) do
    Repo.all(from p in Post, where: p.site_id == ^site_id, order_by: [desc: p.publish_at])
  end

  @doc """
  Lists the published posts of the scope's site (not drafts, `publish_at`
  reached), newest first.
  """
  @spec list_published_posts(Scope.t(), DateTime.t()) :: [Post.t()]
  def list_published_posts(%Scope{site: %Site{id: site_id}}, now \\ DateTime.utc_now()) do
    Repo.all(
      from p in Post,
        where: p.site_id == ^site_id and p.draft == false and p.publish_at <= ^now,
        order_by: [desc: p.publish_at]
    )
  end

  @doc """
  Gets a post of the scope's site by public id. Raises if not found.
  """
  @spec get_post!(Scope.t(), String.t()) :: Post.t()
  def get_post!(%Scope{site: %Site{id: site_id}}, public_id) do
    Repo.one!(from p in Post, where: p.site_id == ^site_id and p.public_id == ^public_id)
  end

  @doc """
  Gets a post of the scope's site by slug, or nil.
  """
  @spec get_post_by_slug(Scope.t(), String.t()) :: Post.t() | nil
  def get_post_by_slug(%Scope{site: %Site{id: site_id}}, slug) do
    Repo.get_by(Post, site_id: site_id, slug: Slug.normalize(slug))
  end

  @doc "Creates a post in the scope's site."
  @spec create_post(Scope.t(), map()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  def create_post(%Scope{site: %Site{id: site_id}}, attrs) do
    %Post{site_id: site_id}
    |> Post.create_changeset(attrs)
    |> save_with_images(:post_id)
  end

  @doc "Updates a post."
  @spec update_post(Scope.t(), Post.t(), map()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  def update_post(%Scope{site: %Site{id: site_id}}, %Post{site_id: site_id} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> save_with_images(:post_id)
  end

  @doc """
  Deletes a post and the images embedded in it. A book reviewed by the post
  loses its review.
  """
  @spec delete_post(Scope.t(), Post.t()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  def delete_post(%Scope{site: %Site{id: site_id}}, %Post{site_id: site_id} = post) do
    delete_with_images(post, :post_id)
  end

  @doc "Returns a changeset for a post form."
  @spec change_post(Scope.t(), Post.t(), map()) :: Ecto.Changeset.t()
  def change_post(%Scope{}, %Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  ## Pages

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
  Creates a page in the scope's site. With `add_to_navigation: true` the
  page is appended to the main navigation.
  """
  @spec create_page(Scope.t(), map()) :: {:ok, Page.t()} | {:error, Ecto.Changeset.t()}
  def create_page(%Scope{site: %Site{id: site_id}} = scope, attrs) do
    %Page{site_id: site_id}
    |> Page.create_changeset(attrs)
    |> save_page(scope)
  end

  @doc """
  Updates a page. When `add_to_navigation` is given, the page is added to
  or removed from the main navigation accordingly.
  """
  @spec update_page(Scope.t(), Page.t(), map()) :: {:ok, Page.t()} | {:error, Ecto.Changeset.t()}
  def update_page(%Scope{site: %Site{id: site_id}} = scope, %Page{site_id: site_id} = page, attrs) do
    page
    |> Page.changeset(attrs)
    |> save_page(scope)
  end

  defp save_page(changeset, scope) do
    navigation_given? = Map.has_key?(changeset.params || %{}, "add_to_navigation")

    Repo.transact(fn ->
      with {:ok, page} <- save_with_images(changeset, :page_id) do
        if navigation_given? do
          sync_navigation(scope, page)
        end

        {:ok, put_navigation_flag(page)}
      end
    end)
  end

  defp sync_navigation(scope, %Page{add_to_navigation: true} = page) do
    {:ok, _item} = Sites.add_to_navigation(scope, page)
  end

  defp sync_navigation(scope, %Page{} = page) do
    :ok = Sites.remove_from_navigation(scope, page)
  end

  @doc """
  Deletes a page (and its navigation item) and the images embedded in it.
  """
  @spec delete_page(Scope.t(), Page.t()) :: {:ok, Page.t()} | {:error, Ecto.Changeset.t()}
  def delete_page(%Scope{site: %Site{id: site_id}} = scope, %Page{site_id: site_id} = page) do
    Repo.transact(fn ->
      :ok = Sites.remove_from_navigation(scope, page)
      delete_with_images(page, :page_id)
    end)
  end

  @doc "Returns a changeset for a page form."
  @spec change_page(Scope.t(), Page.t(), map()) :: Ecto.Changeset.t()
  def change_page(%Scope{}, %Page{} = page, attrs \\ %{}) do
    Page.changeset(page, attrs)
  end

  defp put_navigation_flag(%Page{} = page) do
    %{page | add_to_navigation: Sites.in_navigation?(page)}
  end

  defp put_navigation_flags(pages) do
    ids = Enum.map(pages, & &1.id)

    in_navigation =
      Repo.all(
        from n in Feather.Sites.NavigationItem, where: n.page_id in ^ids, select: n.page_id
      )
      |> MapSet.new()

    Enum.map(pages, &%{&1 | add_to_navigation: MapSet.member?(in_navigation, &1.id)})
  end

  ## Projects

  @doc """
  Lists the projects of the scope's site, most recently started first.
  """
  @spec list_projects(Scope.t()) :: [Project.t()]
  def list_projects(%Scope{site: %Site{id: site_id}}) do
    Repo.all(
      from p in Project,
        where: p.site_id == ^site_id,
        order_by: [desc: p.started_at, asc: p.title]
    )
  end

  @doc """
  Gets a project of the scope's site by public id. Raises if not found.
  """
  @spec get_project!(Scope.t(), String.t()) :: Project.t()
  def get_project!(%Scope{site: %Site{id: site_id}}, public_id) do
    Repo.one!(from p in Project, where: p.site_id == ^site_id and p.public_id == ^public_id)
  end

  @doc "Creates a project in the scope's site."
  @spec create_project(Scope.t(), map()) :: {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def create_project(%Scope{site: %Site{id: site_id}}, attrs) do
    %Project{site_id: site_id}
    |> Project.create_changeset(attrs)
    |> save_with_images(:project_id)
  end

  @doc "Updates a project."
  @spec update_project(Scope.t(), Project.t(), map()) ::
          {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def update_project(
        %Scope{site: %Site{id: site_id}},
        %Project{site_id: site_id} = project,
        attrs
      ) do
    project
    |> Project.changeset(attrs)
    |> save_with_images(:project_id)
  end

  @doc "Deletes a project and the images embedded in it."
  @spec delete_project(Scope.t(), Project.t()) ::
          {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def delete_project(%Scope{site: %Site{id: site_id}}, %Project{site_id: site_id} = project) do
    delete_with_images(project, :project_id)
  end

  @doc "Returns a changeset for a project form."
  @spec change_project(Scope.t(), Project.t(), map()) :: Ecto.Changeset.t()
  def change_project(%Scope{}, %Project{} = project, attrs \\ %{}) do
    Project.changeset(project, attrs)
  end

  ## Admin listings

  @doc """
  One page of the scope's posts for the admin, newest `publish_at` first,
  with the thumbnail image and the reviewed book preloaded.
  """
  @spec paginate_posts(Scope.t(), pos_integer() | String.t() | nil) :: Feather.Pagination.t()
  def paginate_posts(%Scope{site: %Site{id: site_id}}, page) do
    from(p in Post,
      where: p.site_id == ^site_id,
      order_by: [desc: p.publish_at, desc: p.inserted_at],
      preload: [:thumbnail_image, :book]
    )
    |> Feather.Pagination.paginate(page)
  end

  @doc """
  One page of the scope's pages that are not in the main navigation, the
  homepage first, then by title, with the thumbnail image preloaded.
  """
  @spec paginate_pages_outside_navigation(Scope.t(), pos_integer() | String.t() | nil) ::
          Feather.Pagination.t()
  def paginate_pages_outside_navigation(%Scope{site: %Site{id: site_id}}, page) do
    from(p in Page,
      left_join: n in Feather.Sites.NavigationItem,
      on: n.page_id == p.id,
      where: p.site_id == ^site_id and is_nil(n.id),
      order_by: [desc: p.slug == "/", asc: p.title, asc: p.inserted_at],
      preload: [:thumbnail_image]
    )
    |> Feather.Pagination.paginate(page)
  end

  @doc """
  Preloads the header and thumbnail image of a post, page or project (for
  the admin forms).
  """
  @spec preload_header_images(record) :: record when record: Post.t() | Page.t() | Project.t()
  def preload_header_images(record) do
    Repo.preload(record, [:header_image, :thumbnail_image])
  end

  ## Shared

  @doc """
  Suggests a free slug for a title in the scope's site (not used by any
  post or page and not reserved), like Rails' `SlugGenerator`: `/my-title`,
  then `/my-title1`, `/my-title2`, ... Returns `""` for a blank title.
  """
  @spec suggest_slug(Scope.t(), String.t()) :: String.t()
  def suggest_slug(%Scope{site: %Site{id: site_id}}, title) when is_binary(title) do
    Slug.suggest(title, fn slug ->
      Repo.exists?(from p in Post, where: p.site_id == ^site_id and p.slug == ^slug) or
        Repo.exists?(from p in Page, where: p.site_id == ^site_id and p.slug == ^slug)
    end)
  end

  @doc """
  The plain text excerpt of a post, page or project: the text of its
  paragraphs, headers and quotes without HTML, at most `length` characters.
  """
  @spec content_excerpt(Post.t() | Page.t() | Project.t(), pos_integer()) :: String.t()
  def content_excerpt(%{content: content}, length \\ 300) do
    Blocks.excerpt(content, length)
  end

  @doc """
  The tags of a post, page or project as a list.
  """
  @spec tag_list(Post.t() | Page.t() | Project.t()) :: [String.t()]
  def tag_list(record), do: Tags.tag_list(record)

  @doc """
  The content of a post, page or project in Editor.js format, with book
  blocks refreshed from the site's books.
  """
  @spec editor_js(Scope.t(), Post.t() | Page.t() | Project.t()) :: map()
  def editor_js(%Scope{site: %Site{id: site_id} = site}, %{content: content}) do
    book_ids = Blocks.book_ids(content)

    books =
      Repo.all(
        from b in Feather.Books.Book,
          where: b.site_id == ^site_id and b.public_id in ^book_ids
      )
      |> Map.new(&{&1.public_id, &1})

    Blocks.to_editor_js(content, site, books)
  end

  defp save_with_images(%Ecto.Changeset{} = changeset, owner_field) do
    changeset = Media.validate_site_images(changeset, [:header_image_id, :thumbnail_image_id])

    Repo.transact(fn ->
      with {:ok, record} <- Repo.insert_or_update(changeset) do
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

  defp delete_with_images(record, owner_field) do
    images = Media.list_images_owned_by(owner_field, record.id)

    with {:ok, record} <- Repo.delete(record) do
      Enum.each(images, &Media.delete_image/1)
      {:ok, record}
    end
  end
end
