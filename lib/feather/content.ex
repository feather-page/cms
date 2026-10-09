defmodule Feather.Content do
  @moduledoc """
  Posts, pages and projects of a site.

  Every function takes a `%Scope{}` whose `site` is set (see
  `Feather.Accounts.Scope.put_site/2`) and only sees that site's records.
  Records are looked up by public id.

  Saving content assigns the images referenced by its image blocks to the
  record (`images.post_id` / `page_id` / `project_id`), like Rails did.
  Deleting a record deletes the images embedded in it.

  A record holds its unpublished changes: saving it does not change what
  the site shows. Publishing copies its fields into a new, numbered version
  (`PostVersion`, `PageVersion`, `ProjectVersion`) and points
  `published_version_id` at it. Versions copy the header and
  thumbnail image ids, not image rows: images stay owned by the record.
  Deleting a record deletes its versions.

  ## Saving

  Creating or updating a record only stores it; publishing is a step of
  its own (`publish/2`). Posts and pages also take the option `draft:`
  (the content API's field), applied in the same transaction as the save:
  `draft: false` publishes the saved record, `draft: true` makes it a draft
  (unpublishing it if it was published) that keeps the saved changes.
  Where `publish/2` refuses the slug, the save fails with "has already
  been taken" on `:slug`.

  Every save that changes a record's fields (forms, the content API,
  `sync_content/4`, `discard_changes/2`, `restore_version/3`) increments
  its `lock_version`, and a save based on an older `lock_version` fails
  with the error "was changed elsewhere" on `:lock_version`. So an editor
  open in two tabs cannot overwrite the other tab's changes unnoticed.
  Publishing and unpublishing only move the published version and leave
  the counter.
  """

  import Ecto.Query, warn: false

  alias Feather.Repo
  alias Feather.Accounts.Scope
  alias Feather.Content.{Blocks, Page, PageVersion, Post, PostVersion, Project, ProjectVersion}
  alias Feather.Content.{BlocksType, ProseMirror, Slug, Tags}
  alias Feather.Books
  alias Feather.Media
  alias Feather.Media.Cleanup
  alias Feather.Pagination
  alias Feather.Sites
  alias Feather.Sites.Site

  @lock_opts [stale_error_field: :lock_version, stale_error_message: "was changed elsewhere"]

  @versioned_schemas [
    {Post, PostVersion, :post_id},
    {Page, PageVersion, :page_id},
    {Project, ProjectVersion, :project_id}
  ]
  @versions Map.new(@versioned_schemas, fn {schema, version_schema, field} ->
              {schema, {version_schema, field}}
            end)

  @doc """
  The schemas of the records that have versions, each as `{record schema,
  version schema, owner field}`; the owner field names the record in its
  versions and in the images it owns.
  """
  @spec versioned_schemas() :: [{module(), module(), atom()}]
  def versioned_schemas, do: @versioned_schemas

  ## Posts

  @doc """
  Lists the posts of the scope's site, newest `publish_at` first.
  """
  @spec list_posts(Scope.t()) :: [Post.t()]
  def list_posts(%Scope{site: %Site{id: site_id}}) do
    Repo.all(from p in Post, where: p.site_id == ^site_id, order_by: [desc: p.publish_at])
  end

  @doc """
  Gets a post of the scope's site by public id. Raises if not found.
  """
  @spec get_post!(Scope.t(), String.t()) :: Post.t()
  def get_post!(%Scope{site: %Site{id: site_id}}, public_id) do
    Repo.one!(from p in Post, where: p.site_id == ^site_id and p.public_id == ^public_id)
  end

  @doc """
  Gets a post of the scope's site by public id, or nil.
  """
  @spec get_post(Scope.t(), String.t()) :: Post.t() | nil
  def get_post(%Scope{site: %Site{id: site_id}}, public_id) do
    Repo.one(from p in Post, where: p.site_id == ^site_id and p.public_id == ^public_id)
  end

  @doc """
  One page of the scope's posts, newest `publish_at` first, with header
  and thumbnail images preloaded. Pages beyond the last one are empty (the content API).
  """
  @spec paginate_posts(Scope.t(), pos_integer() | String.t() | nil) :: Pagination.t()
  def paginate_posts(%Scope{site: %Site{id: site_id}}, page) do
    from(p in Post,
      where: p.site_id == ^site_id,
      order_by: [desc: p.publish_at, asc: p.id],
      preload: [:header_image, :thumbnail_image]
    )
    |> Pagination.paginate(page, out_of_range: :empty)
  end

  @doc """
  Gets a post of the scope's site by slug, or nil.
  """
  @spec get_post_by_slug(Scope.t(), String.t()) :: Post.t() | nil
  def get_post_by_slug(%Scope{site: %Site{id: site_id}}, slug) do
    Repo.get_by(Post, site_id: site_id, slug: Slug.normalize(slug))
  end

  @doc """
  Creates a post in the scope's site, as a draft unless `draft: false` is
  given (see "Saving" in the module doc).
  """
  @spec create_post(Scope.t(), map(), keyword()) ::
          {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  def create_post(%Scope{site: %Site{id: site_id}} = scope, attrs, opts \\ []) do
    %Post{site_id: site_id}
    |> Post.create_changeset(attrs)
    |> save_with_images(scope, :post_id, opts)
  end

  @doc """
  Updates a post: stores the changes as its unpublished changes (`draft:`,
  see "Saving" in the module doc).
  """
  @spec update_post(Scope.t(), Post.t(), map(), keyword()) ::
          {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  def update_post(
        %Scope{site: %Site{id: site_id}} = scope,
        %Post{site_id: site_id} = post,
        attrs,
        opts \\ []
      ) do
    post
    |> Post.changeset(attrs)
    |> save_with_images(scope, :post_id, opts)
  end

  @doc """
  Deletes a post and the images it owns that nothing else uses. A book reviewed by the post
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
  given (see "Saving" in the module doc). With `add_to_navigation: true`
  the page is appended to the main navigation.
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
  see "Saving" in the module doc). When `add_to_navigation` is given, the
  page is added to or removed from the main navigation accordingly.
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
      with {:ok, page} <- save_with_images(changeset, scope, :page_id, opts) do
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
  Deletes a page (and its navigation item) and the images it owns that nothing else uses.
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

  defp put_navigation_flag(record), do: record

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
  def create_project(%Scope{site: %Site{id: site_id}} = scope, attrs) do
    %Project{site_id: site_id}
    |> Project.create_changeset(attrs)
    |> save_with_images(scope, :project_id, [])
  end

  @doc "Updates a project."
  @spec update_project(Scope.t(), Project.t(), map()) ::
          {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def update_project(
        %Scope{site: %Site{id: site_id}} = scope,
        %Project{site_id: site_id} = project,
        attrs
      ) do
    project
    |> Project.changeset(attrs)
    |> save_with_images(scope, :project_id, [])
  end

  @doc "Deletes a project and the images it owns that nothing else uses."
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

  ## Autosave

  @doc """
  Autosaves the fields of a post, page or project form of the scope's
  site: `attrs` (string keys, as the form sends them) are validated as on
  save, the fields that fail validation are left out and the others are
  saved into the unpublished changes, building on the record's
  `lock_version`. A field left out keeps its stored value until a later
  autosave brings it valid.

  A new record (without id) is created as a draft with the first autosave
  whose remaining fields are valid; until its required fields are valid
  it is not created and the changeset tells why.

  Image and book blocks in `content` whose image or book is not one of the
  site's are left out, like in `sync_content/4`.

  The option `:lock_version` names the counter the attrs were built on
  when that may not be the record's, e.g. form values LiveView recovers
  after a reconnect: unless it is the record's `lock_version`, attrs that
  would change the record are stale.

  Returns the saved record (the record itself when nothing changed),
  `{:error, :stale}` when the record was changed elsewhere, or `{:error,
  changeset}` when nothing could be saved.
  """
  @spec autosave(Scope.t(), record, map(), keyword()) ::
          {:ok, record} | {:error, :stale | Ecto.Changeset.t()}
        when record: Post.t() | Page.t() | Project.t()
  def autosave(
        %Scope{site: %Site{id: site_id}} = scope,
        %schema{site_id: site_id} = record,
        attrs,
        opts \\ []
      )
      when is_map_key(@versions, schema) and is_map(attrs) do
    attrs = keep_site_references(attrs, scope)
    valid_attrs = Map.drop(attrs, invalid_params(schema.changeset(record, attrs)))
    lock_version = Keyword.get(opts, :lock_version, record.lock_version)

    cond do
      is_nil(record.id) -> create_record(scope, schema, valid_attrs)
      unchanged?(schema.changeset(record, valid_attrs)) -> {:ok, record}
      lock_version != record.lock_version -> {:error, :stale}
      true -> scope |> update_record(record, valid_attrs) |> stale_error()
    end
  end

  # The editor hands in image and book ids the browser had: an image or book
  # of another site (or none at all) is left out, like a block without one.
  # A book block takes its details from the bookshelf.
  defp keep_site_references(%{"content" => content} = attrs, scope) do
    case BlocksType.cast(content) do
      {:ok, blocks} -> Map.put(attrs, "content", site_references_only(blocks, scope))
      _invalid -> attrs
    end
  end

  defp keep_site_references(attrs, _scope), do: attrs

  defp site_references_only(blocks, scope) do
    images = MapSet.new(Media.site_image_ids(scope, Blocks.image_ids(blocks)))
    books = Books.books_by_public_id(scope, Blocks.book_ids(blocks))

    for block <- blocks, site_reference?(block, images, books), do: refresh_book(block, books)
  end

  defp refresh_book(%{"type" => "book"} = block, books), do: Blocks.put_book(block, books)
  defp refresh_book(block, _books), do: block

  defp site_reference?(%{"type" => "image"} = block, images, _books),
    do: MapSet.member?(images, block["image_id"])

  defp site_reference?(%{"type" => "book"} = block, _images, books),
    do: Map.has_key?(books, block["book_public_id"])

  defp site_reference?(_block, _images, _books), do: true

  # Project links have no ids, so casting them always looks like a change.
  defp unchanged?(changeset), do: Ecto.Changeset.apply_changes(changeset) == changeset.data

  defp invalid_params(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, _opts} -> message end)
    |> Map.keys()
    |> Enum.flat_map(&param_names/1)
  end

  defp param_names(:links), do: ["links", "links_sort", "links_drop"]
  defp param_names(field), do: [Atom.to_string(field)]

  defp create_record(scope, Post, attrs), do: create_post(scope, attrs)
  defp create_record(scope, Page, attrs), do: create_page(scope, attrs)
  defp create_record(scope, Project, attrs), do: create_project(scope, attrs)

  defp update_record(scope, %Post{} = post, attrs), do: update_post(scope, post, attrs)
  defp update_record(scope, %Page{} = page, attrs), do: update_page(scope, page, attrs)

  defp update_record(scope, %Project{} = project, attrs),
    do: update_project(scope, project, attrs)

  @typedoc """
  A sync of the editor (see `sync_content/4`): the `lock_version` it builds
  on, the ids of all top-level blocks in their new `order` (nil when the
  structure did not change) and the top-level ProseMirror nodes that
  changed.
  """
  @type sync :: %{
          lock_version: integer() | nil,
          order: [String.t()] | nil,
          blocks: [ProseMirror.pm_node()]
        }

  @doc """
  Saves a sync of the editor into the content (the unpublished changes) of
  a post, page or project of the scope's site.

  The synced nodes are converted and sanitized with
  `Feather.Content.ProseMirror.from_node/1` and replace the blocks with
  their ids; nodes that are not blocks are ignored, and so are image
  nodes whose `image_id` is not an image of the site and book nodes whose
  `book_public_id` is not a book of the site. Book blocks take title,
  author and emoji from the bookshelf (`Feather.Content.Blocks.put_book/2`).
  The order then arranges the blocks; blocks it leaves out are dropped and
  new blocks need it. Without an order the blocks keep theirs.

  `record` is the record as the caller last saved or loaded it. The
  sync's `lock_version` is accepted when it lies between the option
  `:base` (default: the record's `lock_version`) and the record's
  `lock_version`: an editor counts as building on the record when it
  names a counter the caller handed out since `base`, e.g. while a field
  save of the same view advanced the counter (nil counts as 0, a record
  the caller created). Any other counter, and a record changed elsewhere
  since the caller's copy, return `{:error, :stale}` and save nothing,
  also when the sync would change nothing.

  An accepted sync is idempotent: one that changes nothing saves nothing
  and returns the stored record with its current `lock_version`.
  """
  @spec sync_content(Scope.t(), record, sync(), keyword()) ::
          {:ok, record} | {:error, :stale | Ecto.Changeset.t()}
        when record: Post.t() | Page.t() | Project.t()
  def sync_content(
        %Scope{site: %Site{id: site_id}} = scope,
        %schema{site_id: site_id} = record,
        %{lock_version: lock_version, order: order, blocks: nodes},
        opts \\ []
      )
      when is_map_key(@versions, schema) do
    base = Keyword.get(opts, :base, record.lock_version)
    current = Repo.get!(schema, record.id)
    content = merge_blocks(current.content, synced_blocks(scope, nodes), order)

    cond do
      (lock_version || 0) not in base..record.lock_version//1 or
          current.lock_version != record.lock_version ->
        {:error, :stale}

      content == current.content ->
        {:ok, put_navigation_flag(current)}

      true ->
        {_version_schema, owner_field} = Map.fetch!(@versions, schema)

        current
        |> Ecto.Changeset.change(content: content)
        |> save_with_images(scope, owner_field, [])
        |> case do
          {:ok, saved} -> {:ok, put_navigation_flag(saved)}
          error -> stale_error(error)
        end
    end
  end

  @doc """
  The content of a sync (see `sync_content/4`) for a record that does not
  exist yet, as a ProseMirror document: the synced nodes in the sync's
  order (or as sent without one). For `autosave/4`, which creates the
  record.
  """
  @spec synced_doc(sync()) :: ProseMirror.doc()
  def synced_doc(%{order: order, blocks: blocks}) do
    nodes = for %{"attrs" => %{"id" => id}} = node <- blocks, is_binary(id), do: {id, node}

    nodes =
      case order do
        nil ->
          Enum.map(nodes, &elem(&1, 1))

        order ->
          by_id = Map.new(nodes)
          Enum.flat_map(order, &List.wrap(by_id[&1]))
      end

    %{"type" => "doc", "content" => nodes}
  end

  defp synced_blocks(scope, nodes) do
    blocks =
      for node <- nodes,
          %{"id" => id} = block <- [ProseMirror.from_node(node)],
          is_binary(id),
          do: block

    site_references_only(blocks, scope)
  end

  defp merge_blocks(content, synced, order) do
    synced = Map.new(synced, &{&1["id"], &1})

    blocks = content |> Map.new(&{&1["id"], &1}) |> Map.merge(synced)

    (order || Enum.map(content, & &1["id"]))
    |> Enum.uniq()
    |> Enum.flat_map(&List.wrap(blocks[&1]))
  end

  defp stale_error({:error, %Ecto.Changeset{errors: errors} = changeset}) do
    if Keyword.has_key?(errors, :lock_version),
      do: {:error, :stale},
      else: {:error, changeset}
  end

  defp stale_error(result), do: result

  ## Publishing

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
  """
  @spec publish(Scope.t(), record) :: {:ok, record} | {:error, :stale | :slug_taken}
        when record: Post.t() | Page.t() | Project.t()
  def publish(%Scope{site: %Site{id: site_id}} = scope, %schema{site_id: site_id} = record)
      when is_map_key(@versions, schema) do
    Repo.transact(fn ->
      with {:ok, current} <- stored(record) do
        current = Repo.preload(current, :published_version)

        cond do
          publication_status(current) == :published -> {:ok, current}
          published_slug_taken?(current) -> {:error, :slug_taken}
          true -> insert_version(scope, current)
        end
      end
    end)
  end

  # The record as stored, while it has the given one's lock_version.
  defp stored(%schema{id: id, lock_version: lock_version}) do
    case Repo.get(schema, id) do
      %{lock_version: ^lock_version} = current -> {:ok, put_navigation_flag(current)}
      _changed_or_deleted -> {:error, :stale}
    end
  end

  defp published_slug_taken?(%{slug: nil}), do: false

  defp published_slug_taken?(%schema{id: id, site_id: site_id, slug: slug}) do
    Enum.any?(Slug.url_space(schema), fn other ->
      {version_schema, _owner_field} = Map.fetch!(@versions, other)

      Repo.exists?(
        from r in other,
          join: v in ^version_schema,
          on: v.id == r.published_version_id,
          where: r.site_id == ^site_id and r.id != ^id and v.slug == ^slug
      )
    end)
  end

  defp insert_version(%Scope{user: user} = scope, %schema{} = record) do
    {version_schema, owner_field} = Map.fetch!(@versions, schema)

    version =
      version_schema
      |> struct(Map.take(record, version_schema.copied_fields()))
      |> Map.merge(%{
        owner_field => record.id,
        number: next_version_number(scope, record),
        published_by_id: user && user.id,
        published_at: DateTime.utc_now()
      })
      |> Repo.insert!()

    put_published_version(record, version)
    {:ok, %{record | published_version_id: version.id, published_version: version}}
  end

  # Publishing leaves the record's unpublished changes, so its updated_at
  # and lock_version, as they are.
  defp put_published_version(%schema{id: id}, version) do
    Repo.update_all(from(r in schema, where: r.id == ^id),
      set: [published_version_id: version && version.id]
    )
  end

  @doc """
  Unpublishes a post, page or project: it becomes a draft and leaves the
  site. Its versions and its unpublished changes stay, so does its
  `updated_at`.
  """
  @spec unpublish(Scope.t(), record) :: {:ok, record}
        when record: Post.t() | Page.t() | Project.t()
  def unpublish(%Scope{site: %Site{id: site_id}}, %schema{site_id: site_id} = record)
      when is_map_key(@versions, schema) do
    put_published_version(record, nil)
    {:ok, %{record | published_version_id: nil, published_version: nil}}
  end

  @doc """
  Returns true if the post, page or project is a draft: it was never
  published or was unpublished.
  """
  @spec draft?(Post.t() | Page.t() | Project.t()) :: boolean()
  def draft?(%{published_version_id: id}), do: is_nil(id)

  @doc """
  Whether the post, page or project is a `:draft`, `:published` as it is,
  or published with `:unpublished_changes`: fields that differ from its
  published version. Loads the published version unless preloaded.
  """
  @spec publication_status(Post.t() | Page.t() | Project.t()) ::
          :draft | :published | :unpublished_changes
  def publication_status(%{published_version_id: nil}), do: :draft

  def publication_status(record) do
    %{published_version: %version_schema{} = version} = Repo.preload(record, :published_version)
    fields = version_schema.copied_fields()

    if Map.take(record, fields) == Map.take(version, fields),
      do: :published,
      else: :unpublished_changes
  end

  @doc """
  Discards the unpublished changes of a published post, page or project:
  puts the fields of its published version back into it.

  Like `publish/2` it acts on the record as stored: `{:error, :stale}`
  when it was changed elsewhere since the given one, `{:error,
  :not_published}` for a draft (also one unpublished elsewhere).
  """
  @spec discard_changes(Scope.t(), record) ::
          {:ok, record} | {:error, :stale | :not_published | Ecto.Changeset.t()}
        when record: Post.t() | Page.t() | Project.t()
  def discard_changes(%Scope{site: %Site{id: site_id}}, %schema{site_id: site_id} = record)
      when is_map_key(@versions, schema) do
    with {:ok, current} <- stored(record) do
      case Repo.preload(current, :published_version) do
        %{published_version: %{} = version} = current -> put_version_fields(current, version)
        _draft -> {:error, :not_published}
      end
    end
  end

  @doc """
  Restores a version of a post, page or project into its unpublished
  changes: puts the version's fields into the record. The published
  version stays; publish to make the restored state public. A version of
  another record raises `Ecto.NoResultsError`. Fails with `{:error,
  :stale}` when the record was changed elsewhere since the given one and
  with a changeset error when another record has taken the version's
  slug meanwhile.
  """
  @spec restore_version(Scope.t(), record, PostVersion.t() | PageVersion.t() | ProjectVersion.t()) ::
          {:ok, record} | {:error, :stale | Ecto.Changeset.t()}
        when record: Post.t() | Page.t() | Project.t()
  def restore_version(%Scope{} = scope, %{} = record, %{id: version_id}) do
    version = Repo.one!(where(versions_query(scope, record), id: ^version_id))
    put_version_fields(record, version)
  end

  @doc """
  Gets the version with the given `number` of a post, page or project of
  the scope's site, or nil.
  """
  @spec get_version(Scope.t(), Post.t() | Page.t() | Project.t(), integer()) ::
          PostVersion.t() | PageVersion.t() | ProjectVersion.t() | nil
  def get_version(%Scope{} = scope, %{} = record, number) when is_integer(number) do
    Repo.one(where(versions_query(scope, record), number: ^number))
  end

  @doc """
  Gets the version with the given `number` of a post, page or project of
  the scope's site. Raises `Ecto.NoResultsError` if it has no such version.
  """
  @spec get_version!(Scope.t(), Post.t() | Page.t() | Project.t(), integer()) ::
          PostVersion.t() | PageVersion.t() | ProjectVersion.t()
  def get_version!(%Scope{} = scope, %{} = record, number) when is_integer(number) do
    Repo.one!(where(versions_query(scope, record), number: ^number))
  end

  defp put_version_fields(record, %version_schema{} = version) do
    record
    |> Ecto.Changeset.change(Map.take(version, version_schema.copied_fields()))
    |> Slug.unsafe_validate_unique()
    |> Ecto.Changeset.unique_constraint([:site_id, :slug],
      error_key: :slug,
      message: "has already been taken"
    )
    |> lock()
    # Forced, so a stale record that already looks like the version is
    # rejected instead of leaving the newer state untouched.
    |> Repo.update([force: true] ++ @lock_opts)
    |> stale_error()
  end

  @doc """
  Lists the versions of a post, page or project, newest first, with the
  member who published each preloaded.
  """
  @spec list_versions(Scope.t(), Post.t() | Page.t() | Project.t()) :: [
          PostVersion.t() | PageVersion.t() | ProjectVersion.t()
        ]
  def list_versions(%Scope{} = scope, %{} = record) do
    Repo.all(
      from v in versions_query(scope, record),
        order_by: [desc: v.number],
        preload: :published_by
    )
  end

  defp versions_query(%Scope{site: %Site{id: site_id}}, %schema{site_id: site_id} = record)
       when is_map_key(@versions, schema) do
    {version_schema, owner_field} = Map.fetch!(@versions, schema)
    from v in version_schema, where: field(v, ^owner_field) == ^record.id
  end

  defp next_version_number(scope, record) do
    latest = Repo.one(from v in versions_query(scope, record), select: max(v.number))
    (latest || 0) + 1
  end

  @doc """
  The posts, pages or projects as their published versions show them: the
  version's fields in place of the unpublished changes. Drafts are left
  out; the order is kept.
  """
  @spec as_published([record]) :: [record] when record: Post.t() | Page.t() | Project.t()
  def as_published(records) do
    for %{published_version: %version_schema{} = version} = record <-
          Repo.preload(records, :published_version) do
      struct(record, Map.take(version, version_schema.copied_fields()))
    end
  end

  ## Admin listings

  @doc """
  One page of the scope's posts for the admin, newest `publish_at` first,
  with the thumbnail image, the reviewed book and the published version
  preloaded.
  """
  @spec paginate_admin_posts(Scope.t(), pos_integer() | String.t() | nil) ::
          Pagination.t()
  def paginate_admin_posts(%Scope{site: %Site{id: site_id}}, page) do
    from(p in Post,
      where: p.site_id == ^site_id,
      order_by: [desc: p.publish_at, desc: p.inserted_at],
      preload: [:thumbnail_image, :book, :published_version]
    )
    |> Pagination.paginate(page)
  end

  @doc """
  One page of the scope's pages that are not in the main navigation, the
  homepage first, then by title, with the thumbnail image preloaded.
  """
  @spec paginate_pages_outside_navigation(Scope.t(), pos_integer() | String.t() | nil) ::
          Pagination.t()
  def paginate_pages_outside_navigation(%Scope{site: %Site{id: site_id}}, page) do
    from(p in Page,
      left_join: n in Feather.Sites.NavigationItem,
      on: n.page_id == p.id,
      where: p.site_id == ^site_id and is_nil(n.id),
      order_by: [desc: p.slug == "/", asc: p.title, asc: p.inserted_at],
      preload: [:thumbnail_image]
    )
    |> Pagination.paginate(page)
  end

  ## Shared

  @doc """
  Suggests a free slug for a title in the scope's site, like Rails'
  `SlugGenerator`: `/my-title`, then `/my-title1`, `/my-title2`, ...
  Returns `""` for a blank title. The slug is free in the URL space of
  `except`, the record being edited (`Feather.Content.Slug.url_space/1`,
  posts and pages without it), and not reserved unless `except` is a
  project. The slug of `except` itself counts as free.
  """
  @spec suggest_slug(Scope.t(), String.t(), Post.t() | Page.t() | Project.t() | nil) ::
          String.t()
  def suggest_slug(%Scope{site: %Site{id: site_id}}, title, except \\ nil)
      when is_binary(title) do
    {schema, except_id} =
      case except do
        %schema{id: id} -> {schema, id}
        nil -> {Post, nil}
      end

    Slug.suggest(title, &Slug.taken?(schema, site_id, &1, except_id),
      own_namespace: schema == Project
    )
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
  The content of a post, page or project as a ProseMirror document for the
  admin editor, with book nodes refreshed from the site's books.
  """
  @spec editor_doc(Scope.t(), Post.t() | Page.t() | Project.t()) :: ProseMirror.doc()
  def editor_doc(%Scope{site: %Site{} = site} = scope, %{content: content}) do
    books = Books.books_by_public_id(scope, Blocks.book_ids(content))
    ProseMirror.to_doc(content, site, books)
  end

  @doc """
  Preloads the header and thumbnail image of a post, page or project.
  """
  @spec preload_images(record) :: record when record: Post.t() | Page.t() | Project.t()
  def preload_images(record), do: Repo.preload(record, [:header_image, :thumbnail_image])

  @doc """
  Preloads the published version of a post, page or project (nil for a
  draft), unless it is loaded.
  """
  @spec preload_published_version(record) :: record when record: Post.t() | Page.t() | Project.t()
  def preload_published_version(record), do: Repo.preload(record, :published_version)

  defp save_with_images(%Ecto.Changeset{} = changeset, scope, owner_field, opts) do
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

        case Keyword.fetch(opts, :draft) do
          {:ok, false} -> scope |> publish(record) |> slug_taken_error(changeset)
          {:ok, true} -> unpublish(scope, record)
          :error -> {:ok, record}
        end
      end
    end)
  end

  defp slug_taken_error({:error, :slug_taken}, changeset) do
    action = if changeset.data.__meta__.state == :loaded, do: :update, else: :insert
    changeset = Ecto.Changeset.add_error(changeset, :slug, "has already been taken")
    {:error, %{changeset | action: action}}
  end

  defp slug_taken_error(result, _changeset), do: result

  # Updates of a stored record increment `lock_version` and only apply
  # while it still has the value the changeset's data was loaded with.
  defp lock(%Ecto.Changeset{data: %{__meta__: %{state: :loaded}}} = changeset),
    do: Ecto.Changeset.optimistic_lock(changeset, :lock_version)

  defp lock(changeset), do: changeset

  # The record's images are deleted unless something else still uses them,
  # see Feather.Media.Cleanup.delete_released/1.
  defp delete_with_images(record, owner_field) do
    images = Media.list_images_owned_by(owner_field, record.id)

    result =
      Repo.transact(fn ->
        with {:ok, record} <- Repo.delete(record) do
          {:ok, {record, Cleanup.delete_released(images)}}
        end
      end)

    with {:ok, {record, deleted}} <- result do
      Enum.each(deleted, &Media.delete_image_files/1)
      {:ok, record}
    end
  end
end
