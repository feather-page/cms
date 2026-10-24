defmodule Feather.StaticSite.Routes do
  @moduledoc """
  The address scheme of a static site, in both directions: it builds every
  URL and output path of the export and resolves a requested path back to
  a record (for the preview).

  | Record             | URL                                | Output path                           |
  |--------------------|------------------------------------|---------------------------------------|
  | home, page 1       | `/`                                | `index.html`                          |
  | home, page n > 1   | `/page/n/`                         | `page/n/index.html`                   |
  | post with slug     | `/<slug>/`                         | `<slug>/index.html`                   |
  | post without slug  | `/posts/<public id, lower>/`       | `posts/<public id, lower>/index.html` |
  | page               | `/<slug>/` (homepage: `/`)         | `<slug>/index.html`                   |
  | project            | `/projects/<slug>/`                | `projects/<slug>/index.html`          |
  | Markdown alternate | its page's URL + `index.md`        | `index.md` beside its `index.html`    |
  | image variant      | `/images/<public id>/<file>`       | `images/<public id>/<file>`           |
  | generated image    | `/images/<hash>.png`               | `images/<hash>.png`                   |
  | replier's picture  | `/images/replies/<name>.webp`      | `images/replies/<name>.webp`          |
  | theme font         | `/fonts/<file>?v=<hash>`           | `fonts/<file>`                        |
  | diagram            | `/diagrams/<hash>.svg`             | `diagrams/<hash>.svg`                 |
  | artifact           | `/feed.xml`, `/llms.txt`, ...      | `feed.xml`, `llms.txt`, ...           |
  | not found page     | (any missing path)                 | `404.html`                            |
  | Apache rules       | (not served)                       | `.htaccess`                           |
  | WebFinger answer   | `/.well-known/webfinger`           | `.well-known/webfinger`               |
  | fediverse account  | `/activitypub/<name>`              | `activitypub/<name>`                  |
  | its outbox         | `/activitypub/outbox`              | `activitypub/outbox`                  |
  | its followers      | `/activitypub/followers`           | `activitypub/followers`               |
  | whom it follows    | `/activitypub/following`           | `activitypub/following`               |
  | post document      | `/activitypub/posts/<public id>`   | `activitypub/posts/<public id>`       |
  | member's reply     | `/activitypub/replies/<public id>` | `activitypub/replies/<public id>`     |

  The home page (its first page), posts, projects and pages have a
  Markdown alternate; the homepage's is the home page's. The fediverse
  documents (ADR 0033) exist only for a site with a fediverse name; they
  have no extension, and their addresses never derive from slugs. From its
  second `fediverse_generation` n on, a post's document is at its public
  id followed by `-n`.

  URLs are relative to `site_root`: `/` for a deployed site (`public/1`),
  `/preview/<site public id>/` for the preview. `canonical/1` returns the
  same routes against the site's public address (`https://<domain>/`),
  used by the feed, the sitemap, `robots.txt`, `llms.txt`, the Markdown
  alternates and the fediverse documents.
  """

  import Ecto.Query, warn: false

  alias Feather.Content.{Page, Post, Project, Slug}
  alias Feather.Diagrams
  alias Feather.Fediverse.{MemberReply, Mention, Pictures}
  alias Feather.Media.{Image, Variants}
  alias Feather.Repo
  alias Feather.Sites.Site
  alias Feather.StaticSite.{GeneratedImages, Precompress, Themes}

  @activitypub "activitypub"
  @webfinger ".well-known/webfinger"

  @enforce_keys [:site, :site_root, :canonical_url]
  defstruct [:site, :site_root, :canonical_url]

  @type t :: %__MODULE__{site: Site.t(), site_root: String.t(), canonical_url: String.t()}

  @type activitypub_document ::
          :account | :outbox | :followers | :following | Post.t() | MemberReply.t()

  @type route ::
          {:home, pos_integer()}
          | {:artifact, String.t()}
          | {:image, Image.t(), Variants.variant()}
          | {:generated_image, String.t()}
          | {:reply_picture, String.t()}
          | {:font, String.t()}
          | {:diagram, String.t()}
          | {:project, Project.t()}
          | {:post, Post.t()}
          | {:page, Page.t()}
          | {:markdown, :home | Post.t() | Page.t() | Project.t()}

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
  Routes for the deployed site: from `/`, canonically at its public
  address `https://<site domain>/`.
  """
  @spec public(Site.t()) :: t()
  def public(%Site{} = site), do: new(site, canonical_url: public_url(site))

  @doc """
  Routes for the preview of a site: from `/preview/<site public id>/`,
  canonically at `https://<site domain>/`.
  """
  @spec preview(Site.t()) :: t()
  def preview(%Site{} = site),
    do: new(site, site_root: "/preview/#{site.public_id}/", canonical_url: public_url(site))

  defp public_url(%Site{domain: domain}), do: "https://#{domain}/"

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

  @doc "The URL of a post, page or project."
  @spec record_url(t(), Post.t() | Page.t() | Project.t()) :: String.t()
  def record_url(routes, %Post{} = post), do: post_url(routes, post)
  def record_url(routes, %Page{} = page), do: page_url(routes, page)
  def record_url(routes, %Project{} = project), do: project_url(routes, project)

  @doc """
  The URL of the Markdown alternate of the home page (`:home`), a post,
  page or project (`Feather.StaticSite.MarkdownAlternate`), next to its
  page.
  """
  @spec markdown_url(t(), :home | Post.t() | Page.t() | Project.t()) :: String.t()
  def markdown_url(%__MODULE__{} = routes, :home), do: home_url(routes) <> "index.md"
  def markdown_url(%__MODULE__{} = routes, record), do: record_url(routes, record) <> "index.md"

  @doc """
  The paths `resolve/2` finds a post, page or project or its Markdown
  alternate at, relative to the site root and without a trailing slash:
  its URL, the URL with `/index.html` and `/index.md` and, for a post or
  page, the URL with `.html`.
  """
  @spec record_paths(t(), Post.t() | Page.t() | Project.t()) :: [String.t()]
  def record_paths(%__MODULE__{site_root: root} = routes, record) do
    case routes |> record_url(record) |> String.replace_prefix(root, "") |> strip_slug() do
      "" ->
        ["/", "/index.html", "/index.md"]

      segment ->
        ["/" <> segment, "/#{segment}/index.html", "/#{segment}/index.md"] ++
          html_path(record, segment)
    end
  end

  defp html_path(%Project{}, _segment), do: []
  defp html_path(_post_or_page, segment), do: ["/" <> segment <> ".html"]

  @doc """
  The URL of an image variant, by variant or file name (`"640.webp"`).
  Raises for anything that names no variant.
  """
  @spec image_url(t(), Image.t(), Variants.variant() | String.t()) :: String.t()
  def image_url(%__MODULE__{site_root: root}, %Image{} = image, variant),
    do: root <> image_segment(image, variant)

  @doc """
  The URL of a favicon or share card by its file name (see
  `Feather.StaticSite.GeneratedImages`).
  """
  @spec generated_image_url(t(), String.t()) :: String.t()
  def generated_image_url(%__MODULE__{site_root: root}, name),
    do: root <> generated_image_segment(name)

  @doc """
  The URL of the picture of an approved reply's author by its file name
  (see `Feather.Fediverse.Pictures`).
  """
  @spec reply_picture_url(t(), String.t()) :: String.t()
  def reply_picture_url(%__MODULE__{site_root: root}, name),
    do: root <> reply_picture_segment(name)

  @doc """
  The `srcset` of an image shown with the webp variants of the given
  sizes: narrowest first, with their real widths (see
  `Feather.Media.Variants.srcset_widths/3`).
  """
  @spec image_srcset(t(), Image.t(), [pos_integer()]) :: String.t()
  def image_srcset(%__MODULE__{} = routes, %Image{} = image, sizes) do
    sizes
    |> Variants.srcset_widths(image.width, image.height)
    |> Enum.map_join(", ", fn {variant, width} ->
      "#{image_url(routes, image, variant)} #{width}w"
    end)
  end

  @doc """
  The URL of a font file of the site's theme (see `Feather.StaticSite.Theme`),
  with a hash of its content, so a changed font reaches browsers despite
  the year-long cache.
  """
  @spec font_url(t(), String.t()) :: String.t()
  def font_url(%__MODULE__{site_root: root, site: site} = routes, name),
    do: root <> font_segment(routes, name) <> "?v=" <> font_hash(site, name)

  @doc "The URL of a rendered diagram by its file name (see `Feather.Diagrams`)."
  @spec diagram_url(t(), String.t()) :: String.t()
  def diagram_url(%__MODULE__{site_root: root}, name), do: root <> diagram_segment(name)

  @doc """
  The URL of a generated file at the site root (`feed.xml`, `robots.txt`,
  `sitemap.xml`, `style.css`). Raises for anything else.
  """
  @spec artifact_url(t(), String.t()) :: String.t()
  def artifact_url(%__MODULE__{site_root: root}, name), do: root <> artifact(name)

  @doc """
  The URL of a fediverse document of the site (ADR 0033): its account
  (`:account`, by the site's fediverse name), the account's `:outbox`,
  `:followers` or `:following`, or the document of a post (by its public
  id and its `fediverse_generation`) or a member's reply (by its public
  id).
  """
  @spec activitypub_url(t(), activitypub_document()) :: String.t()
  def activitypub_url(%__MODULE__{site_root: root} = routes, document),
    do: root <> activitypub_path(routes, document)

  @doc "The URL of a path relative to the site root (`/feed.xml`)."
  @spec path_url(t(), String.t()) :: String.t()
  def path_url(%__MODULE__{site_root: root}, path), do: root <> String.trim_leading(path, "/")

  @doc "The URL of the page web servers show for missing paths."
  @spec not_found_url(t()) :: String.t()
  def not_found_url(%__MODULE__{site_root: root} = routes), do: root <> not_found_path(routes)

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

  @doc "The output path of the Markdown alternate of the home page (`:home`), a post, page or project."
  @spec markdown_path(t(), :home | Post.t() | Page.t() | Project.t()) :: String.t()
  def markdown_path(%__MODULE__{}, :home), do: "index.md"

  def markdown_path(%__MODULE__{} = routes, record),
    do: routes |> record_path(record) |> String.replace_suffix("index.html", "index.md")

  defp record_path(routes, %Post{} = post), do: post_path(routes, post)
  defp record_path(routes, %Page{} = page), do: page_path(routes, page)
  defp record_path(routes, %Project{} = project), do: project_path(routes, project)

  @doc "The output path of an image variant."
  @spec image_path(t(), Image.t(), Variants.variant() | String.t()) :: String.t()
  def image_path(%__MODULE__{}, %Image{} = image, variant), do: image_segment(image, variant)

  @doc "The output path of a favicon or share card."
  @spec generated_image_path(t(), String.t()) :: String.t()
  def generated_image_path(%__MODULE__{}, name), do: generated_image_segment(name)

  @doc "The output path of the picture of an approved reply's author."
  @spec reply_picture_path(t(), String.t()) :: String.t()
  def reply_picture_path(%__MODULE__{}, name), do: reply_picture_segment(name)

  @doc "The output path of a theme font file."
  @spec font_path(t(), String.t()) :: String.t()
  def font_path(%__MODULE__{} = routes, name), do: font_segment(routes, name)

  @doc "The output path of a rendered diagram."
  @spec diagram_path(t(), String.t()) :: String.t()
  def diagram_path(%__MODULE__{}, name), do: diagram_segment(name)

  @doc "The output path of a generated file at the site root."
  @spec artifact_path(t(), String.t()) :: String.t()
  def artifact_path(%__MODULE__{}, name), do: artifact(name)

  @doc "The output path of the page web servers show for missing paths."
  @spec not_found_path(t()) :: String.t()
  def not_found_path(%__MODULE__{}), do: "404.html"

  @doc "The output path of the rules for Apache hosts (see `Feather.StaticSite.Htaccess`)."
  @spec htaccess_path(t()) :: String.t()
  def htaccess_path(%__MODULE__{}), do: ".htaccess"

  @doc "The output path of a fediverse document of the site (see `activitypub_url/2`)."
  @spec activitypub_path(t(), activitypub_document()) :: String.t()
  def activitypub_path(%__MODULE__{site: %Site{fediverse_name: name}}, :account)
      when is_binary(name),
      do: @activitypub <> "/" <> name

  def activitypub_path(%__MODULE__{}, :outbox), do: @activitypub <> "/outbox"
  def activitypub_path(%__MODULE__{}, :followers), do: @activitypub <> "/followers"
  def activitypub_path(%__MODULE__{}, :following), do: @activitypub <> "/following"

  def activitypub_path(%__MODULE__{}, %Post{public_id: public_id, fediverse_generation: n})
      when n > 1,
      do: @activitypub <> "/posts/" <> public_id <> "-" <> Integer.to_string(n)

  def activitypub_path(%__MODULE__{}, %Post{public_id: public_id}),
    do: @activitypub <> "/posts/" <> public_id

  def activitypub_path(%__MODULE__{}, %MemberReply{public_id: public_id}),
    do: @activitypub <> "/replies/" <> public_id

  @doc "The output path of the WebFinger answer, which answers every query (ADR 0033)."
  @spec webfinger_path(t()) :: String.t()
  def webfinger_path(%__MODULE__{}), do: @webfinger

  @doc """
  The output path of the site's IndexNow key file (`<key>.txt`, holding
  the key), or nil for a site without a key.
  """
  @spec indexnow_key_path(t()) :: String.t() | nil
  def indexnow_key_path(%__MODULE__{site: %Site{indexnow_key: nil}}), do: nil
  def indexnow_key_path(%__MODULE__{site: %Site{indexnow_key: key}}), do: key <> ".txt"

  defp artifact(name) do
    name = to_string(name)

    if name in Slug.artifacts(),
      do: name,
      else: raise(ArgumentError, "unknown artifact #{inspect(name)}")
  end

  defp font_segment(%__MODULE__{site: site}, name) do
    if font?(site, name),
      do: "fonts/" <> name,
      else: raise(ArgumentError, "unknown font file #{inspect(name)}")
  end

  # Fonts ship with the release, so each is hashed once per run.
  defp font_hash(site, name) do
    path = Themes.module(site).font_path(name)
    key = {__MODULE__, :font_hash, path}

    with nil <- :persistent_term.get(key, nil) do
      hash = :sha256 |> :crypto.hash(File.read!(path)) |> Base.encode16(case: :lower)
      short = binary_part(hash, 0, 12)
      :persistent_term.put(key, short)
      short
    end
  end

  defp diagram_segment(name) do
    if Diagrams.file_name?(name),
      do: "diagrams/" <> name,
      else: raise(ArgumentError, "unknown diagram file #{inspect(name)}")
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

  defp generated_image_segment(name) do
    if GeneratedImages.file_name?(name),
      do: "images/" <> name,
      else: raise(ArgumentError, "unknown generated image #{inspect(name)}")
  end

  defp reply_picture_segment(name) do
    if Pictures.file_name?(name),
      do: "images/replies/" <> name,
      else: raise(ArgumentError, "unknown reply picture #{inspect(name)}")
  end

  defp strip_slug(nil), do: ""

  defp strip_slug(slug),
    do: slug |> String.trim() |> String.trim_leading("/") |> String.trim_trailing("/")

  ## Resolution

  @doc """
  Resolves a requested path (relative to the site root) to what lives
  there, or nil. Content of other sites is never found; drafts are (the
  preview shows them).

  Precedence for ambiguous paths: home, artifact, generated image, reply
  picture, image, font, diagram, project, post by public id, page, post by
  slug. A trailing `index.html`, `.html` or `/` is ignored. `index.md` is
  the home page's Markdown alternate, a post, page or project path followed
  by `/index.md` its Markdown alternate.
  """
  @spec resolve(t(), String.t() | [String.t()]) :: route() | nil
  def resolve(%__MODULE__{} = routes, segments) when is_list(segments),
    do: resolve(routes, Enum.join(segments, "/"))

  def resolve(%__MODULE__{} = routes, path) when is_binary(path) do
    case normalize_request_path(path) do
      "index.md" -> {:markdown, :home}
      path -> resolve_normalized(routes, path)
    end
  end

  defp resolve_normalized(%__MODULE__{site: %Site{id: site_id} = site} = routes, path) do
    case String.split(path, "/index.md", parts: 2) do
      [record_path, ""] -> resolve_markdown(routes, record_path, path)
      _other -> resolve_with(resolvers(site), path, site_id)
    end
  end

  defp resolve_with(resolvers, path, site_id),
    do: Enum.find_value(resolvers, fn resolver -> resolver.(path, site_id) end)

  defp resolvers(site) do
    [
      &resolve_home/2,
      &resolve_artifact/2,
      &resolve_generated_image/2,
      &resolve_reply_picture/2,
      &resolve_image/2,
      fn path, _site_id -> resolve_font(path, site) end,
      &resolve_diagram/2
    ] ++ record_resolvers()
  end

  defp record_resolvers do
    [
      &resolve_project/2,
      &resolve_post_by_public_id/2,
      &resolve_page/2,
      &resolve_post_by_slug/2
    ]
  end

  # Only the path the export writes: not the .html or upper case forms a page is found at.
  defp resolve_markdown(%__MODULE__{site: site} = routes, record_path, path) do
    with {_kind, record} <- resolve_with(record_resolvers(), record_path, site.id),
         ^path <- markdown_path(routes, record) do
      {:markdown, record}
    else
      _other -> nil
    end
  end

  @doc """
  Returns true if the export writes a file at the path (relative to the
  site root) that `resolve/2` does not serve: the 404 page, the
  `.htaccess`, the IndexNow key file, the precompressed copies of the
  text files (`Feather.StaticSite.Precompress`) and the fediverse
  documents, which own every path below `activitypub/` and the WebFinger
  answer for every site, so that a later fediverse name finds them free.
  """
  @spec unserved_file?(t(), String.t()) :: boolean()
  def unserved_file?(%__MODULE__{} = routes, path) when is_binary(path) do
    path = String.trim_leading(path, "/")

    path in [not_found_path(routes), htaccess_path(routes), indexnow_key_path(routes)] or
      fediverse_path?(path) or precompressed_copy?(routes, path)
  end

  @doc """
  Returns true for the paths the fediverse documents own, relative to the
  site root: `activitypub` and everything below it, and the WebFinger
  answer, precompressed copies included.
  """
  @spec fediverse_path?(String.t()) :: boolean()
  def fediverse_path?(path) when is_binary(path) do
    path = String.trim_leading(path, "/")

    path == @activitypub or String.starts_with?(path, @activitypub <> "/") or
      String.replace(path, ~r/\.(br|gz)\z/, "") == @webfinger
  end

  defp precompressed_copy?(routes, path) do
    case Enum.find(Precompress.suffixes(), &String.ends_with?(path, &1)) do
      nil ->
        false

      suffix ->
        source = String.replace_suffix(path, suffix, "")

        Path.extname(source) in Precompress.extensions() and
          (source in [not_found_path(routes), indexnow_key_path(routes)] or
             resolve(routes, source) != nil)
    end
  end

  @doc """
  The slug a requested path addresses a record by, read like `resolve/2`
  does: `{Project, slug}` under `projects/`, otherwise `{Post, slug}` (a
  post or page, see `Feather.Content.Slug.url_space/1`); nil for the site
  root. A trailing `index.md` (the Markdown alternate) is ignored like
  `index.html`.
  """
  @spec addressed_slug(String.t()) :: {Post | Project, String.t()} | nil
  def addressed_slug(path) when is_binary(path) do
    case path |> normalize_request_path() |> String.replace(~r{(\A|/)index\.md\z}, "") do
      "" -> nil
      "projects/" <> slug -> {Project, "/" <> slug}
      path -> {Post, "/" <> String.replace_suffix(path, ".html", "")}
    end
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

  defp resolve_generated_image("images/" <> name, _site_id),
    do: if(GeneratedImages.file_name?(name), do: {:generated_image, name})

  defp resolve_generated_image(_path, _site_id), do: nil

  # Only the picture of a reply the site shows.
  defp resolve_reply_picture("images/replies/" <> name, site_id) do
    if Pictures.file_name?(name) and
         Repo.exists?(
           from m in Mention,
             where:
               m.site_id == ^site_id and m.approved_picture == ^name and m.approval == :approved
         ),
       do: {:reply_picture, name}
  end

  defp resolve_reply_picture(_path, _site_id), do: nil

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

  defp resolve_font("fonts/" <> name, site), do: if(font?(site, name), do: {:font, name})
  defp resolve_font(_path, _site), do: nil

  defp resolve_diagram("diagrams/" <> name, _site_id),
    do: if(Diagrams.file_name?(name), do: {:diagram, name})

  defp resolve_diagram(_path, _site_id), do: nil

  defp font?(site, name), do: Map.has_key?(Themes.module(site).fonts(), name)

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
