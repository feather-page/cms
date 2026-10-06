defmodule Feather.StaticSite.Routes do
  @moduledoc """
  The address scheme of a static site, in both directions: it builds every
  URL and output path of the export and resolves a requested path back to
  a record (for the preview).

  | Record            | URL                          | Output path                         |
  |-------------------|------------------------------|-------------------------------------|
  | home, page 1      | `/`                          | `index.html`                        |
  | home, page n > 1  | `/page/n/`                   | `page/n/index.html`                 |
  | post with slug    | `/<slug>/`                   | `<slug>/index.html`                 |
  | post without slug | `/posts/<public id, lower>/` | `posts/<public id, lower>/index.html` |
  | page              | `/<slug>/` (homepage: `/`)   | `<slug>/index.html`                 |
  | project           | `/projects/<slug>/`          | `projects/<slug>/index.html`        |
  | image variant     | `/images/<public id>/<file>` | `images/<public id>/<file>`         |
  | artifact          | `/feed.xml`, ...             | `feed.xml`, ...                     |

  URLs are relative to `site_root`: `/` for a deployed site,
  `/preview/<target public id>/` for the preview. `canonical/1` returns the
  same routes against the site's public address (`https://<hostname>/`),
  used by the feed, the sitemap and robots.txt.
  """

  import Ecto.Query, warn: false

  alias Feather.Content.{Page, Post, Project, Slug}
  alias Feather.Media.{Image, Variants}
  alias Feather.Publishing.DeploymentTarget
  alias Feather.Repo
  alias Feather.Sites.Site

  @enforce_keys [:site, :site_root, :canonical_url]
  defstruct [:site, :site_root, :canonical_url]

  @type t :: %__MODULE__{site: Site.t(), site_root: String.t(), canonical_url: String.t()}

  @type route ::
          {:home, pos_integer()}
          | {:artifact, String.t()}
          | {:image, Image.t(), Variants.variant()}
          | {:project, Project.t()}
          | {:post, Post.t()}
          | {:page, Page.t()}

  @doc """
  Routes for a site. `site_root` defaults to `/`, `canonical_url` to the
  site root.
  """
  @spec new(Site.t(), keyword()) :: t()
  def new(%Site{} = site, opts \\ []) do
    site_root = Keyword.get(opts, :site_root, "/")

    %__MODULE__{
      site: site,
      site_root: site_root,
      canonical_url: opts[:canonical_url] || site_root
    }
  end

  @doc """
  Routes for a deployment target (its `site` must be loaded): `:deployed`
  addresses the site from `/`, `:preview` from
  `/preview/<target public id>/`. Both are canonically at
  `https://<public hostname>/`.
  """
  @spec for(DeploymentTarget.t(), :deployed | :preview) :: t()
  def for(%DeploymentTarget{site: %Site{} = site} = target, as \\ :deployed) do
    site_root =
      case as do
        :deployed -> "/"
        :preview -> "/preview/#{target.public_id}/"
      end

    new(site, site_root: site_root, canonical_url: "https://#{target.public_hostname}/")
  end

  @doc "The same routes against the canonical URL."
  @spec canonical(t()) :: t()
  def canonical(%__MODULE__{site_root: root, canonical_url: root} = routes), do: routes

  def canonical(%__MODULE__{canonical_url: url} = routes), do: %{routes | site_root: url}

  ## URLs

  @doc "The URL of a page of the post list (the home page)."
  @spec home_url(t(), pos_integer()) :: String.t()
  def home_url(%__MODULE__{site_root: root}, page \\ 1) do
    if page > 1, do: "#{root}page/#{page}/", else: root
  end

  @doc "The URL of a post."
  @spec post_url(t(), Post.t()) :: String.t()
  def post_url(%__MODULE__{site_root: root}, %Post{} = post), do: "#{root}#{post_segment(post)}/"

  @doc "The URL of a page; the homepage is the site root."
  @spec page_url(t(), Page.t()) :: String.t()
  def page_url(%__MODULE__{site_root: root} = routes, %Page{} = page) do
    if Page.homepage?(page), do: home_url(routes), else: "#{root}#{strip_slug(page.slug)}/"
  end

  @doc "The URL of a project."
  @spec project_url(t(), Project.t()) :: String.t()
  def project_url(%__MODULE__{site_root: root}, %Project{} = project),
    do: "#{root}#{project_segment(project)}/"

  @doc """
  The URL of an image variant, by variant name (`:mobile_x1_webp`) or file
  name (`"mobile_x1.webp"`). Raises for unknown variants.
  """
  @spec image_url(t(), Image.t(), atom() | String.t()) :: String.t()
  def image_url(%__MODULE__{site_root: root}, %Image{} = image, variant),
    do: root <> image_segment(image, variant)

  @doc """
  The `srcset` of an image: every webp variant with its width.
  """
  @spec image_srcset(t(), Image.t()) :: String.t()
  def image_srcset(%__MODULE__{} = routes, %Image{} = image) do
    Variants.srcset_widths()
    |> Enum.map_join(", ", fn {filename, width} ->
      "#{image_url(routes, image, filename)} #{width}w"
    end)
  end

  @doc """
  The URL of a generated file at the site root (`feed.xml`, `robots.txt`,
  `sitemap.xml`). Raises for anything else.
  """
  @spec artifact_url(t(), String.t()) :: String.t()
  def artifact_url(%__MODULE__{site_root: root}, name), do: root <> artifact(name)

  ## Output paths

  @doc "The output path of a page of the post list."
  @spec home_path(t(), pos_integer()) :: String.t()
  def home_path(%__MODULE__{}, page \\ 1) do
    if page > 1, do: "page/#{page}/index.html", else: "index.html"
  end

  @doc "The output path of a post."
  @spec post_path(t(), Post.t()) :: String.t()
  def post_path(%__MODULE__{}, %Post{} = post), do: "#{post_segment(post)}/index.html"

  @doc "The output path of a page; the homepage is `index.html`."
  @spec page_path(t(), Page.t()) :: String.t()
  def page_path(%__MODULE__{} = routes, %Page{} = page) do
    if Page.homepage?(page), do: home_path(routes), else: "#{strip_slug(page.slug)}/index.html"
  end

  @doc "The output path of a project."
  @spec project_path(t(), Project.t()) :: String.t()
  def project_path(%__MODULE__{}, %Project{} = project),
    do: "#{project_segment(project)}/index.html"

  @doc "The output path of an image variant."
  @spec image_path(t(), Image.t(), atom() | String.t()) :: String.t()
  def image_path(%__MODULE__{}, %Image{} = image, variant), do: image_segment(image, variant)

  @doc "The output path of a generated file at the site root."
  @spec artifact_path(t(), String.t()) :: String.t()
  def artifact_path(%__MODULE__{}, name), do: artifact(name)

  defp artifact(name) do
    name = to_string(name)

    if name in Slug.artifacts(),
      do: name,
      else: raise(ArgumentError, "unknown artifact #{inspect(name)}")
  end

  defp post_segment(%Post{slug: slug, public_id: public_id}) do
    case strip_slug(slug) do
      "" -> "posts/#{String.downcase(public_id)}"
      segment -> segment
    end
  end

  defp project_segment(%Project{slug: slug}), do: "projects/#{strip_slug(slug)}"

  defp image_segment(%Image{public_id: public_id}, variant) do
    case Variants.fetch(variant) do
      %{filename: filename} -> "images/#{public_id}/#{filename}"
      nil -> raise ArgumentError, "unknown image variant #{inspect(variant)}"
    end
  end

  defp strip_slug(nil), do: ""

  defp strip_slug(slug),
    do: slug |> String.trim() |> String.trim_leading("/") |> String.trim_trailing("/")

  ## Resolution

  @doc """
  Resolves a requested path (relative to the site root) to what lives
  there, or nil. Content of other sites is never found; drafts are (the
  preview shows them).

  Precedence for ambiguous paths: home, artifact, image, project, post by
  public id, page, post by slug. A trailing `index.html`, `.html` or `/`
  is ignored.
  """
  @spec resolve(t(), String.t() | [String.t()]) :: route() | nil
  def resolve(%__MODULE__{} = routes, segments) when is_list(segments),
    do: resolve(routes, Enum.join(segments, "/"))

  def resolve(%__MODULE__{site: %Site{id: site_id}}, path) when is_binary(path) do
    path = normalize_request_path(path)

    Enum.find_value(
      [
        &resolve_home/2,
        &resolve_artifact/2,
        &resolve_image/2,
        &resolve_project/2,
        &resolve_post_by_public_id/2,
        &resolve_page/2,
        &resolve_post_by_slug/2
      ],
      fn resolver -> resolver.(path, site_id) end
    )
  end

  defp normalize_request_path(path) do
    path
    |> String.trim_leading("/")
    |> String.replace(~r{(\A|/)index\.html\z}, "")
    |> String.trim_trailing("/")
  end

  defp resolve_home(path, _site_id) when path in ["", "index.html", "index"], do: {:home, 1}

  defp resolve_home(path, _site_id) do
    case Regex.run(~r"\Apage/(\d{1,9})\z", path) do
      [_, number] ->
        page = String.to_integer(number)
        if page > 0, do: {:home, page}

      nil ->
        nil
    end
  end

  defp resolve_artifact(path, _site_id), do: if(path in Slug.artifacts(), do: {:artifact, path})

  defp resolve_image(path, site_id) do
    with [_, public_id, filename] <- Regex.run(~r{\Aimages/([^/]+)/([^/]+)\z}, path),
         %{} = variant <- Variants.fetch(filename),
         %Image{} = image <-
           Repo.one(from i in Image, where: i.site_id == ^site_id and i.public_id == ^public_id) do
      {:image, image, variant}
    else
      _ -> nil
    end
  end

  defp resolve_project("projects/" <> slug, site_id) do
    if project = find_by_slug(Project, site_id, slug), do: {:project, project}
  end

  defp resolve_project(_path, _site_id), do: nil

  defp resolve_post_by_public_id("posts/" <> public_id, site_id) do
    public_id = public_id |> String.replace_suffix(".html", "") |> String.downcase()

    post =
      Repo.one(
        from p in Post,
          where: p.site_id == ^site_id and fragment("lower(?)", p.public_id) == ^public_id
      )

    if post, do: {:post, post}
  end

  defp resolve_post_by_public_id(_path, _site_id), do: nil

  defp resolve_page(path, site_id) do
    if page = find_by_slug(Page, site_id, String.replace_suffix(path, ".html", "")),
      do: {:page, page}
  end

  defp resolve_post_by_slug(path, site_id) do
    if post = find_by_slug(Post, site_id, String.replace_suffix(path, ".html", "")),
      do: {:post, post}
  end

  # Slugs are stored with a leading slash; imported data may lack it.
  defp find_by_slug(schema, site_id, slug) do
    case strip_slug(slug) do
      "" ->
        nil

      slug ->
        candidates = ["/" <> slug, slug]

        Repo.one(
          from r in schema,
            where: r.site_id == ^site_id and r.slug in ^candidates,
            order_by: [asc: r.slug],
            limit: 1
        )
    end
  end
end
