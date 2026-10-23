defmodule Feather.Content.Sync do
  @moduledoc """
  Autosaving forms and syncing the editor into the unpublished changes of
  posts, pages and projects, and checking the images and books content
  names, called through `Feather.Content`.
  """

  import Feather.Content.Versions, only: [put_navigation_flag: 1, stale_error: 1]

  alias Feather.Accounts.Scope
  alias Feather.Books
  alias Feather.Content.{Blocks, BlocksType, Page, Post, Project, ProseMirror, Saving}
  alias Feather.Content.{Pages, Posts, Projects, Versions}
  alias Feather.Media
  alias Feather.Repo
  alias Feather.Sites.Site

  @versions Versions.versions()

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

  # The ids come from the browser: blocks of another site's images or books are dropped.
  defp keep_site_references(%{"content" => content} = attrs, scope) do
    case BlocksType.cast(content) do
      {:ok, blocks} -> Map.put(attrs, "content", site_references_only(blocks, scope))
      _invalid -> attrs
    end
  end

  defp keep_site_references(attrs, _scope), do: attrs

  defp site_references_only(blocks, scope) do
    {images, books} = site_references(scope, blocks)
    for block <- blocks, site_reference?(block, images, books), do: refresh_book(block, books)
  end

  @doc """
  Checks that the image and book blocks of `blocks` (normalized) name
  images and books of the scope's site. Returns the blocks with book
  blocks taking title, author and emoji from the bookshelf
  (`Feather.Content.Blocks.put_book/2`), or the references that are not
  the site's as `{block index, type, id}`.
  """
  @spec resolve_references(Scope.t(), [Blocks.block()]) ::
          {:ok, [Blocks.block()]} | {:error, [{non_neg_integer(), String.t(), String.t()}]}
  def resolve_references(%Scope{site: %Site{}} = scope, blocks) when is_list(blocks) do
    {images, books} = site_references(scope, blocks)

    unknown =
      for {block, index} <- Enum.with_index(blocks),
          not site_reference?(block, images, books),
          do: {index, block["type"], reference_id(block)}

    if unknown == [],
      do: {:ok, Enum.map(blocks, &refresh_book(&1, books))},
      else: {:error, unknown}
  end

  defp site_references(scope, blocks) do
    images = MapSet.new(Media.site_image_ids(scope, Blocks.image_ids(blocks)))
    {images, Books.books_by_public_id(scope, Blocks.book_ids(blocks))}
  end

  defp reference_id(%{"type" => "image"} = block), do: block["image_id"]
  defp reference_id(%{"type" => "book"} = block), do: block["book_public_id"]

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

  defp create_record(scope, Post, attrs), do: Posts.create_post(scope, attrs)
  defp create_record(scope, Page, attrs), do: Pages.create_page(scope, attrs)
  defp create_record(scope, Project, attrs), do: Projects.create_project(scope, attrs)

  defp update_record(scope, %Post{} = post, attrs), do: Posts.update_post(scope, post, attrs)
  defp update_record(scope, %Page{} = page, attrs), do: Pages.update_page(scope, page, attrs)

  defp update_record(scope, %Project{} = project, attrs),
    do: Projects.update_project(scope, project, attrs)

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
      stale?(current, record, lock_version, base) -> {:error, :stale}
      content == current.content -> {:ok, put_navigation_flag(current)}
      true -> save_synced_content(current, content)
    end
  end

  defp stale?(current, record, lock_version, base) do
    (lock_version || 0) not in base..record.lock_version//1 or
      current.lock_version != record.lock_version
  end

  defp save_synced_content(%schema{} = current, content) do
    {_version_schema, owner_field} = Map.fetch!(@versions, schema)
    changeset = Ecto.Changeset.change(current, content: content)

    case Saving.save_with_images(changeset, owner_field) do
      {:ok, saved} -> {:ok, put_navigation_flag(saved)}
      error -> stale_error(error)
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
end
