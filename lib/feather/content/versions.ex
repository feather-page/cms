defmodule Feather.Content.Versions do
  @moduledoc """
  The versions of posts, pages and projects and their publication, called
  through `Feather.Content` (see its module doc): publishing turns a
  record into a new, numbered version and points `published_version_id`
  at it.

  Also holds the helpers the content modules share: loading a record as
  stored, optimistic locking and touching the site.
  """

  import Ecto.Query, warn: false

  alias Feather.Accounts.Scope
  alias Feather.Content.{Page, PageVersion, Post, PostVersion, Project, ProjectVersion, Slug}
  alias Feather.Redirects
  alias Feather.Repo
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

  @doc false
  def versions, do: @versions

  @doc false
  def lock_opts, do: @lock_opts

  @doc false
  # Publishes the stored record in the caller's transaction. `state: :unpublished` (the
  # default) publishes a draft or unpublished changes and leaves a published record as it
  # is; `state: :published` publishes a published record again and refuses unpublished
  # changes. `:prepare` changes the stored record before its version is inserted.
  def publish_stored(scope, record, opts \\ []) do
    state = Keyword.get(opts, :state, :unpublished)
    prepare = Keyword.get(opts, :prepare, & &1)

    with {:ok, current} <- stored(record) do
      current = Repo.preload(current, :published_version)

      case {state, publication_status(current)} do
        {:unpublished, :published} -> {:ok, current}
        {:published, :published} -> insert_version_following_url(scope, prepare.(current))
        {:published, _status} -> {:error, :unpublished_changes}
        {:unpublished, _status} -> publish_unpublished(scope, current, prepare)
      end
    end
  end

  defp publish_unpublished(scope, current, prepare) do
    if published_slug_taken?(current),
      do: {:error, :slug_taken},
      else: insert_version_following_url(scope, prepare.(current))
  end

  defp insert_version_following_url(scope, record) do
    previous = as_newest_version(scope, record)

    with {:ok, published} <- insert_version(scope, record),
         :ok <- Redirects.follow_publish(scope, previous, published) do
      {:ok, published}
    end
  end

  defp as_newest_version(scope, record) do
    if version = newest_version(scope, record), do: with_version_fields(record, version)
  end

  @doc false
  def newest_version(_scope, %{id: nil}), do: nil

  def newest_version(scope, record) do
    Repo.one(from v in versions_query(scope, record), order_by: [desc: v.number], limit: 1)
  end

  @doc false
  def stored(%schema{id: id, lock_version: lock_version}) do
    case Repo.get(schema, id) do
      %{lock_version: ^lock_version} = current -> {:ok, put_navigation_flag(current)}
      _changed_or_deleted -> {:error, :stale}
    end
  end

  defp published_slug_taken?(%{slug: nil}), do: false

  defp published_slug_taken?(%schema{id: id, site_id: site_id, slug: slug}),
    do: published_with_slug?(schema, site_id, slug, id)

  @doc """
  Returns true if a record of the scope's site in the URL space of
  `schema` (`Feather.Content.Slug.url_space/1`) is published with the
  slug. The record with id `except_id` does not count.
  """
  @spec published_slug?(Scope.t(), module(), String.t(), Ecto.UUID.t() | nil) :: boolean()
  def published_slug?(%Scope{site: %Site{id: site_id}}, schema, slug, except_id \\ nil),
    do: published_with_slug?(schema, site_id, slug, except_id)

  @doc false
  def published_with_slug?(schema, site_id, slug, except_id) do
    Enum.any?(Slug.url_space(schema), fn other ->
      {version_schema, _owner_field} = Map.fetch!(@versions, other)

      query =
        from r in other,
          join: v in ^version_schema,
          on: v.id == r.published_version_id,
          where: r.site_id == ^site_id and v.slug == ^slug

      query = if except_id, do: where(query, [r], r.id != ^except_id), else: query
      Repo.exists?(query)
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

  # update_all keeps the record's updated_at and lock_version.
  defp put_published_version(%schema{id: id}, version) do
    Repo.update_all(from(r in schema, where: r.id == ^id),
      set: [published_version_id: version.id]
    )
  end

  @doc """
  Unpublishes a post, page or project: it becomes a draft and leaves the
  site. Its versions and its unpublished changes stay, so does its
  `updated_at`; the site's `updated_at` moves if it was published.
  """
  @spec unpublish(Scope.t(), record) :: {:ok, record}
        when record: Post.t() | Page.t() | Project.t()
  def unpublish(%Scope{site: %Site{id: site_id}} = scope, %schema{site_id: site_id} = record)
      when is_map_key(@versions, schema) do
    Repo.transact(fn ->
      {unpublished, _} =
        Repo.update_all(
          from(r in schema, where: r.id == ^record.id and not is_nil(r.published_version_id)),
          set: [published_version_id: nil]
        )

      :ok = touch_site_if(unpublished > 0, scope)
      {:ok, %{record | published_version_id: nil, published_version: nil}}
    end)
  end

  @doc """
  Returns true if the post, page or project is a draft: it was never
  published or was unpublished.
  """
  @spec draft?(Post.t() | Page.t() | Project.t()) :: boolean()
  def draft?(%{published_version_id: id}), do: is_nil(id)

  @doc """
  Returns true if the post is due at `now`: its `publish_at` has passed,
  so the export shows it once it is published.
  """
  @spec due?(Post.t(), DateTime.t()) :: boolean()
  def due?(%Post{publish_at: nil}, _now), do: false
  def due?(%Post{publish_at: publish_at}, now), do: DateTime.compare(publish_at, now) != :gt

  @doc """
  Returns true if the stored post, page or project is published, whatever
  the given struct, which may be stale, says.
  """
  @spec stored_published?(Post.t() | Page.t() | Project.t()) :: boolean()
  def stored_published?(%schema{id: id}) when is_map_key(@versions, schema),
    do: Repo.exists?(from r in schema, where: r.id == ^id and not is_nil(r.published_version_id))

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
  When the post, page or project last changed on the site: when its
  published version was published, for a post scheduled past that its
  `publish_at`. Nil for a draft. Loads the published version unless
  preloaded.
  """
  @spec last_changed_at(Post.t() | Page.t() | Project.t()) :: DateTime.t() | nil
  def last_changed_at(%Post{published_version: %PostVersion{published_at: published_at}} = post),
    do: [published_at, post.publish_at] |> Enum.reject(&is_nil/1) |> Enum.max(DateTime)

  def last_changed_at(%{published_version: %{published_at: published_at}}), do: published_at

  def last_changed_at(%{published_version: %Ecto.Association.NotLoaded{}} = record),
    do: record |> preload_published_version() |> last_changed_at()

  def last_changed_at(%{published_version: nil}), do: nil

  @doc """
  Like `last_changed_at/1`, but a draft (which the preview shows) dates
  from its `updated_at`.
  """
  @spec last_changed_or_updated_at(Post.t() | Page.t() | Project.t()) :: DateTime.t()
  def last_changed_or_updated_at(record), do: last_changed_at(record) || record.updated_at

  @doc """
  Discards the unpublished changes of a published post, page or project:
  puts the fields of its published version back into it.

  Like `Feather.Content.publish/2` it acts on the record as stored:
  `{:error, :stale}` when it was changed elsewhere since the given one,
  `{:error, :not_published}` for a draft (also one unpublished elsewhere).
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
    # Forced, so a stale record that already matches the version is still rejected.
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
    for %{published_version: %{} = version} = record <-
          Repo.preload(records, :published_version),
        do: with_version_fields(record, version)
  end

  defp with_version_fields(record, %version_schema{} = version),
    do: struct(record, Map.take(version, version_schema.copied_fields()))

  @doc """
  Preloads the published version of a post, page or project (nil for a
  draft), unless it is loaded.
  """
  @spec preload_published_version(record) :: record when record: Post.t() | Page.t() | Project.t()
  def preload_published_version(record), do: Repo.preload(record, :published_version)

  @doc false
  def put_navigation_flag(%Page{} = page) do
    %{page | add_to_navigation: Sites.in_navigation?(page)}
  end

  def put_navigation_flag(record), do: record

  @doc false
  def lock(%Ecto.Changeset{data: %{__meta__: %{state: :loaded}}} = changeset),
    do: Ecto.Changeset.optimistic_lock(changeset, :lock_version)

  def lock(changeset), do: changeset

  @doc false
  def stale_error({:error, %Ecto.Changeset{errors: errors} = changeset}) do
    if Keyword.has_key?(errors, :lock_version),
      do: {:error, :stale},
      else: {:error, changeset}
  end

  def stale_error(result), do: result

  @doc false
  def touch_site_if(true, scope), do: Sites.touch_site(scope)
  def touch_site_if(false, _scope), do: :ok
end
