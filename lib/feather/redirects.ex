defmodule Feather.Redirects do
  @moduledoc """
  Redirects of a site: from an old path to a post, page or project, or to
  a path the site generates (ADR 0025).

  Every function takes a `%Scope{}` whose `site` is set and only sees that
  site's redirects, looked up by public id. Every change to a redirect
  moves the site's `updated_at`.
  """

  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias Feather.Accounts.Scope
  alias Feather.Content
  alias Feather.Content.{Page, Post, Project, Slug}
  alias Feather.Redirects.Redirect
  alias Feather.Repo
  alias Feather.Sites
  alias Feather.Sites.Site
  alias Feather.StaticSite.Routes

  @stale_opts [stale_error_field: :stale]

  @doc """
  Lists the redirects of the scope's site by old path, with their target
  records preloaded as published (`Feather.Content.as_published/1`, a
  draft as it is) and `target` set to the URL each leads to.
  """
  @spec list_redirects(Scope.t()) :: [Redirect.t()]
  def list_redirects(%Scope{site: %Site{id: site_id} = site}) do
    routes = Routes.new(site)

    from(r in Redirect, where: r.site_id == ^site_id, order_by: [asc: r.old_path])
    |> Repo.all()
    |> Repo.preload(target_preloads())
    |> Enum.map(&put_target_url(&1, routes))
  end

  @doc "Gets a redirect of the scope's site like `list_redirects/1` does, or nil."
  @spec get_redirect(Scope.t(), String.t()) :: Redirect.t() | nil
  def get_redirect(%Scope{site: %Site{} = site}, public_id) do
    if redirect = Repo.one(redirect_query(site, public_id)), do: with_target(redirect, site)
  end

  @doc """
  Gets a redirect of the scope's site like `list_redirects/1` does.
  Raises `Ecto.NoResultsError` if the site has no such redirect.
  """
  @spec get_redirect!(Scope.t(), String.t()) :: Redirect.t()
  def get_redirect!(%Scope{site: %Site{} = site}, public_id),
    do: site |> redirect_query(public_id) |> Repo.one!() |> with_target(site)

  @doc """
  Gets the active redirect of the scope's site whose old path a requested
  path (a string or path segments) matches, with or without a trailing
  slash, or nil. Unlike `get_redirect/2` its target record is as it is
  and `target` its current URL, where the preview shows it.
  """
  @spec find_active_redirect(Scope.t(), String.t() | [String.t()]) :: Redirect.t() | nil
  def find_active_redirect(%Scope{} = scope, segments) when is_list(segments),
    do: find_active_redirect(scope, Enum.join(segments, "/"))

  def find_active_redirect(%Scope{site: %Site{} = site} = scope, path) do
    with old_path when is_binary(old_path) <- Slug.normalize(path),
         %Redirect{} = redirect <- Repo.one(from_path(site, old_path)),
         redirect = with_target(redirect, site, :current),
         true <- active?(scope, redirect) do
      redirect
    else
      _ -> nil
    end
  end

  defp redirect_query(%Site{id: site_id}, public_id),
    do: from(r in Redirect, where: r.site_id == ^site_id and r.public_id == ^public_id)

  @doc """
  Creates a redirect for the scope's site. Its old path must be no URL
  the site serves, as it is or as published, and no other redirect's; its
  target must resolve and is stored as the post, page, project or path it
  leads to.
  """
  @spec create_redirect(Scope.t(), map()) :: {:ok, Redirect.t()} | {:error, Changeset.t()}
  def create_redirect(%Scope{site: %Site{id: site_id} = site} = scope, attrs) do
    %Redirect{site_id: site_id}
    |> Redirect.create_changeset(attrs)
    |> validate(scope)
    |> save(scope, &Repo.insert/1)
    |> with_saved_target(site)
  end

  @doc """
  Creates a permanent redirect for each line of `text` that is not blank:
  its old path and its target separated by whitespace, each validated like
  `create_redirect/2`. Returns the trimmed lines with their results, in
  order.
  """
  @spec create_redirects(Scope.t(), String.t()) ::
          [{String.t(), {:ok, Redirect.t()} | {:error, Changeset.t()}}]
  def create_redirects(%Scope{site: %Site{}} = scope, text) when is_binary(text) do
    text
    |> String.split(~r/\R/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&{&1, create_redirect(scope, line_attrs(&1))})
  end

  defp line_attrs(line) do
    case String.split(line, ~r/\s+/, parts: 2) do
      [old_path, target] -> %{old_path: old_path, target: target, kind: :permanent}
      [old_path] -> %{old_path: old_path, kind: :permanent}
    end
  end

  @doc """
  Updates a redirect of the scope's site. Returns `{:error, :stale}` for
  one deleted since it was loaded.
  """
  @spec update_redirect(Scope.t(), Redirect.t(), map()) ::
          {:ok, Redirect.t()} | {:error, Changeset.t() | :stale}
  def update_redirect(
        %Scope{site: %Site{id: site_id} = site} = scope,
        %Redirect{site_id: site_id} = redirect,
        attrs
      ) do
    changeset = change_redirect_for(redirect, scope, attrs)

    # `target` is virtual: what it resolves to is stored in the other fields.
    if changeset.valid? and Map.keys(changeset.changes) -- [:target] == [] do
      {:ok, with_target(redirect, site)}
    else
      changeset |> save(scope, &Repo.update(&1, @stale_opts)) |> with_saved_target(site)
    end
  end

  @doc """
  Deletes a redirect of the scope's site. Returns `{:error, :stale}` for
  one deleted since it was loaded.
  """
  @spec delete_redirect(Scope.t(), Redirect.t()) :: {:ok, Redirect.t()} | {:error, :stale}
  def delete_redirect(
        %Scope{site: %Site{id: site_id}} = scope,
        %Redirect{site_id: site_id} = redirect
      ) do
    save(redirect, scope, &Repo.delete(&1, @stale_opts))
  end

  @doc """
  Follows the publish of a post, page or project of the scope's site:
  deletes the redirects from its URL and the URL's `index.html`, and
  redirects the URL it was last published at (`previous`, the record as
  published then, or nil) to it permanently, replacing a redirect from
  that path, unless another record holds that URL as it is or as
  published. Moves the site's `updated_at` if a redirect changed.
  """
  @spec follow_publish(Scope.t(), record | nil, record) :: :ok
        when record: Post.t() | Page.t() | Project.t()
  def follow_publish(
        %Scope{site: %Site{id: site_id} = site} = scope,
        previous,
        %{site_id: site_id} = record
      ) do
    routes = Routes.new(site)
    path = url_path(routes, record)
    # On Apache a redirect from the URL's index.html would loop; one from its .html form leads on.
    {deleted, _} = Repo.delete_all(from_path(site, [path, Path.join(path, "index.html")]))
    redirected? = redirect_previous_url(scope, routes, previous, path)

    if deleted > 0 or redirected?, do: Sites.touch_site(scope), else: :ok
  end

  defp redirect_previous_url(_scope, _routes, nil, _path), do: false

  defp redirect_previous_url(%Scope{site: site} = scope, routes, %schema{id: id} = previous, path) do
    old_path = url_path(routes, previous)

    if old_path != path and Redirect.valid_path?(old_path) and
         not held?(scope, routes, old_path, previous) do
      Repo.delete_all(from_path(site, old_path))

      %Redirect{site_id: site.id, old_path: old_path, kind: :permanent}
      |> Changeset.change(%{Redirect.target_field(schema) => id})
      |> Feather.PublicId.put()
      |> Repo.insert!()

      true
    else
      false
    end
  end

  defp held?(scope, routes, path, except) do
    case {Routes.resolve(routes, path), except} do
      {nil, _except} ->
        Routes.unserved_file?(routes, path) or published_by_other?(scope, path, except)

      {{_kind, %schema{id: id}}, %schema{id: id}} ->
        published_by_other?(scope, path, except)

      _content_or_generated ->
        true
    end
  end

  defp published_by_other?(scope, path, except) do
    case Routes.addressed_slug(path) do
      nil -> false
      {schema, slug} -> Content.published_slug?(scope, schema, slug, except && except.id)
    end
  end

  defp from_path(%Site{id: site_id}, old_paths) when is_list(old_paths),
    do: from(r in Redirect, where: r.site_id == ^site_id and r.old_path in ^old_paths)

  defp from_path(%Site{id: site_id}, old_path),
    do: from(r in Redirect, where: r.site_id == ^site_id and r.old_path == ^old_path)

  defp url_path(routes, record), do: Slug.normalize(Routes.record_url(routes, record))

  @doc "Returns a changeset for a redirect form, validated like a save."
  @spec change_redirect(Scope.t(), Redirect.t(), map()) :: Changeset.t()
  def change_redirect(%Scope{site: %Site{} = site} = scope, %Redirect{} = redirect, attrs \\ %{}) do
    change_redirect_for(%{redirect | site_id: site.id}, scope, attrs)
  end

  defp change_redirect_for(redirect, scope, attrs),
    do: redirect |> Redirect.changeset(attrs) |> validate(scope)

  @doc """
  Returns true if the redirect leads somewhere now: its target record is
  published (a post also due, `Feather.Content.due?/2`), or its target
  path resolves. Needs the targets preloaded.
  """
  @spec active?(Scope.t(), Redirect.t()) :: boolean()
  def active?(%Scope{site: %Site{}}, %Redirect{target_path: nil} = redirect) do
    case Redirect.target_record(redirect) do
      %Post{} = post -> not Content.draft?(post) and Content.due?(post, DateTime.utc_now())
      record -> not Content.draft?(record)
    end
  end

  def active?(%Scope{site: %Site{} = site}, %Redirect{target_path: path}),
    do: Routes.resolve(Routes.new(site), path) != nil

  defp save(changeset_or_redirect, scope, operation) do
    result =
      Repo.transact(fn ->
        with {:ok, redirect} <- operation.(changeset_or_redirect),
             :ok <- Sites.touch_site(scope) do
          {:ok, redirect}
        end
      end)

    stale_error(result)
  end

  defp stale_error({:error, %Changeset{errors: errors} = changeset}),
    do: if(Keyword.has_key?(errors, :stale), do: {:error, :stale}, else: {:error, changeset})

  defp stale_error(result), do: result

  defp validate(changeset, %Scope{site: site} = scope) do
    routes = Routes.new(site)

    changeset
    |> validate_old_path(scope, routes)
    |> Changeset.unsafe_validate_unique([:site_id, :old_path], Repo,
      error_key: :old_path,
      message: "already has a redirect"
    )
    |> put_target(routes)
  end

  defp validate_old_path(changeset, scope, routes) do
    Changeset.validate_change(changeset, :old_path, fn :old_path, old_path ->
      if held?(scope, routes, old_path, nil),
        do: [old_path: "is already a URL of the site"],
        else: []
    end)
  end

  defp put_target(changeset, routes) do
    case Changeset.fetch_change(changeset, :target) do
      {:ok, target} when is_binary(target) -> put_resolved(changeset, routes, target)
      _unchanged -> changeset
    end
  end

  defp put_resolved(changeset, routes, target) do
    case Routes.resolve(routes, target) do
      nil ->
        Changeset.add_error(changeset, :target, "does not lead to anything on the site")

      {_kind, %schema{id: id}} ->
        put_targets(changeset, %{Redirect.target_field(schema) => id})

      route ->
        put_targets(changeset, %{target_path: route_path(routes, route)})
    end
  end

  defp put_targets(changeset, target) do
    cleared = Map.new([:target_path | Redirect.target_fields()], &{&1, nil})
    Changeset.change(changeset, Map.merge(cleared, target))
  end

  defp route_path(routes, {:home, page}), do: Routes.home_url(routes, page)
  defp route_path(routes, {:artifact, name}), do: Routes.artifact_url(routes, name)
  defp route_path(routes, {:image, image, variant}), do: Routes.image_url(routes, image, variant)
  defp route_path(routes, {:font, name}), do: "/" <> Routes.font_path(routes, name)
  defp route_path(routes, {:diagram, name}), do: Routes.diagram_url(routes, name)

  defp route_path(routes, {:generated_image, name}),
    do: Routes.generated_image_url(routes, name)

  defp with_saved_target({:ok, redirect}, site), do: {:ok, with_target(redirect, site)}
  defp with_saved_target(error, _site), do: error

  defp with_target(redirect, site, content \\ :published) do
    redirect
    |> Repo.preload(target_preloads(), force: true)
    |> put_target_url(Routes.new(site), content)
  end

  defp target_preloads, do: Enum.map(Redirect.target_assocs(), &{&1, :published_version})

  defp put_target_url(redirect, routes, content \\ :published) do
    redirect = if content == :published, do: as_published_target(redirect), else: redirect
    %{redirect | target: target_url(routes, redirect)}
  end

  defp as_published_target(redirect) do
    case Enum.find(Redirect.target_assocs(), &Map.fetch!(redirect, &1)) do
      nil -> redirect
      assoc -> Map.update!(redirect, assoc, &as_published/1)
    end
  end

  defp as_published(record) do
    case Content.as_published([record]) do
      [published] -> published
      [] -> record
    end
  end

  defp target_url(_routes, %Redirect{target_path: path}) when is_binary(path), do: path

  defp target_url(routes, redirect),
    do: Routes.record_url(routes, Redirect.target_record(redirect))
end
