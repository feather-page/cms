defmodule Feather.StaticSite.Renderer do
  @moduledoc """
  Renders the pages and files of a static site from `SiteData` and
  `Routes`, the pages through the site's theme (`Feather.StaticSite.Theme`).
  Used by the export and the preview alike, so both show the same markup.
  Every function returns iodata and touches no database.
  """

  use Gettext, backend: Feather.StaticSite.Gettext

  alias Feather.Content.Blocks, as: ContentBlocks
  alias Feather.Content.{HTML, Page, Post, Project}
  alias Feather.Media.Image

  alias Feather.StaticSite.{
    Blocks,
    Feed,
    HTMLFormatter,
    Routes,
    SiteData,
    Sitemap,
    ThemeHelpers,
    Themes
  }

  alias Phoenix.HTML.Safe

  @posts_per_page 25
  @description_length 155

  @doc "The number of posts on a page of the post list."
  @spec posts_per_page() :: pos_integer()
  def posts_per_page, do: @posts_per_page

  @doc "The number of pages of the post list (at least 1)."
  @spec total_pages(SiteData.t()) :: pos_integer()
  def total_pages(%SiteData{posts: posts}), do: max(ceil(length(posts) / @posts_per_page), 1)

  @doc """
  A page of the post list. Pages past the end list no posts.
  """
  @spec render_home(SiteData.t(), Routes.t(), pos_integer()) :: iodata()
  def render_home(%SiteData{} = data, %Routes{} = routes, page_number \\ 1) do
    homepage = data.homepage || %Page{content: [], header_image: nil}

    assigns =
      data
      |> base_assigns(routes, data.site.title, data.site.emoji, true)
      |> Map.merge(home_sharing(data, routes, homepage, page_number))
      |> Map.merge(%{
        masthead_image: homepage.header_image,
        rss_url: Routes.artifact_url(routes, "feed.xml"),
        posts: posts_on_page(data, page_number),
        current_page: page_number,
        total_pages: total_pages(data)
      })

    render(:home, assigns)
  end

  defp posts_on_page(data, page_number),
    do: Enum.slice(data.posts, (page_number - 1) * @posts_per_page, @posts_per_page)

  defp home_sharing(data, routes, homepage, page_number) do
    sharing(
      routes,
      &Routes.home_url(&1, page_number),
      ContentBlocks.excerpt(homepage.content),
      homepage.header_image || first_image(data, homepage.content)
    )
  end

  @doc "A post (its book, header and thumbnail image preloaded)."
  @spec render_post(SiteData.t(), Routes.t(), Post.t()) :: iodata()
  def render_post(%SiteData{} = data, %Routes{} = routes, %Post{} = post) do
    label = in_site_language(data, fn -> ThemeHelpers.post_label(post) end)
    {newer, older} = SiteData.neighbours(data, post)

    assigns =
      data
      |> base_assigns(routes, post_heading(data, post), post.emoji, false, label)
      |> Map.merge(post_sharing(data, routes, post))
      |> Map.merge(%{
        post: post,
        published_at: post.publish_at,
        header_image: post.header_image,
        newer_post: newer,
        older_post: older
      })

    render(:post, assigns)
  end

  defp post_heading(data, post), do: if(blank?(post.title), do: data.site.title, else: post.title)

  defp post_sharing(data, routes, post) do
    sharing(
      routes,
      &Routes.post_url(&1, post),
      ContentBlocks.excerpt(post.content),
      post.header_image || post.thumbnail_image || first_image(data, post.content),
      "article"
    )
  end

  @doc "A page (its header image preloaded)."
  @spec render_page(SiteData.t(), Routes.t(), Page.t()) :: iodata()
  def render_page(%SiteData{} = data, %Routes{} = routes, %Page{} = page) do
    assigns =
      data
      |> base_assigns(routes, page.title, page.emoji, false)
      |> Map.merge(
        sharing(
          routes,
          &Routes.page_url(&1, page),
          ContentBlocks.excerpt(page.content),
          page.header_image || first_image(data, page.content)
        )
      )
      |> Map.merge(%{
        page: page,
        header_image: page.header_image,
        title_mascot: if(page.page_type == "projects", do: data.site.projects_mascot_image)
      })

    render(:page, assigns)
  end

  @doc "A project (its header and thumbnail image preloaded)."
  @spec render_project(SiteData.t(), Routes.t(), Project.t()) :: iodata()
  def render_project(%SiteData{} = data, %Routes{} = routes, %Project{} = project) do
    assigns =
      data
      |> base_assigns(routes, project.title, project.emoji, false)
      |> Map.merge(project_sharing(data, routes, project))
      |> Map.merge(%{
        project: project,
        header_image: project.header_image,
        trail: projects_trail(data, routes)
      })

    render(:project, assigns)
  end

  defp project_sharing(data, routes, project) do
    sharing(
      routes,
      &Routes.project_url(&1, project),
      project_summary(project),
      project.header_image || project.thumbnail_image || first_image(data, project.content)
    )
  end

  defp project_summary(project) do
    if blank?(project.short_description),
      do: ContentBlocks.excerpt(project.content),
      else: ContentBlocks.strip_tags(project.short_description)
  end

  @doc "The page shown for paths that do not exist."
  @spec render_not_found(SiteData.t(), Routes.t()) :: iodata()
  def render_not_found(%SiteData{} = data, %Routes{} = routes) do
    title = in_site_language(data, fn -> gettext("Page not found") end)

    assigns =
      data
      |> base_assigns(routes, title, nil, false)
      |> Map.merge(%{noindex: true, projects_page: projects_page(data)})

    render(:not_found, assigns)
  end

  @doc """
  A generated file at the site root: `feed.xml`, `sitemap.xml`,
  `robots.txt` or `style.css` (the theme's font faces and stylesheet).
  """
  @spec render_artifact(SiteData.t(), Routes.t(), String.t()) :: iodata()
  def render_artifact(%SiteData{} = data, %Routes{} = routes, "feed.xml"),
    do:
      in_site_language(data, fn ->
        Feed.render(data, routes, block_context(data, Routes.canonical(routes)))
      end)

  def render_artifact(%SiteData{} = data, %Routes{} = routes, "sitemap.xml"),
    do: Sitemap.render(data, routes)

  def render_artifact(%SiteData{}, %Routes{} = routes, "robots.txt") do
    sitemap = routes |> Routes.canonical() |> Routes.artifact_url("sitemap.xml")
    "User-agent: *\nAllow: /\n\nSitemap: #{sitemap}\n"
  end

  def render_artifact(%SiteData{} = data, %Routes{} = routes, "style.css"),
    do: stylesheet(data.site, routes)

  @doc "The content type of a generated file at the site root."
  @spec artifact_content_type(String.t()) :: String.t()
  def artifact_content_type("feed.xml"), do: "application/rss+xml"
  def artifact_content_type("sitemap.xml"), do: "application/xml"
  def artifact_content_type("robots.txt"), do: "text/plain"
  def artifact_content_type("style.css"), do: "text/css"

  @doc "The context for rendering blocks of the site."
  @spec block_context(SiteData.t(), Routes.t()) :: Blocks.context()
  def block_context(%SiteData{} = data, %Routes{} = routes) do
    Blocks.context(routes,
      content_image_sizes: Themes.module(data.site).content_image_sizes(),
      images: data.images,
      books: data.books_by_public_id,
      diagrams: data.diagrams,
      highlights: data.highlights
    )
  end

  defp base_assigns(data, routes, page_title, page_emoji, is_home, meta_title \\ nil) do
    meta_title = meta_title || page_title

    %{
      data: data,
      site: data.site,
      routes: routes,
      ctx: block_context(data, routes),
      social_links: Enum.filter(data.social_links, &HTML.safe_url?(&1.url)),
      page_title: page_title,
      meta_title: meta_title,
      document_title: document_title(data.site.title, meta_title, is_home),
      stylesheet_url: stylesheet_url(data.site, routes),
      description: nil,
      canonical_url: nil,
      og_type: "website",
      og_image_url: nil,
      page_emoji: if(blank?(page_emoji), do: nil, else: page_emoji),
      is_home: is_home,
      trail: [],
      header_image: nil,
      title_mascot: nil,
      published_at: nil,
      noindex: false,
      masthead_image: nil,
      rss_url: nil,
      __changed__: nil
    }
  end

  defp stylesheet(site, routes) do
    theme = Themes.module(site)
    [theme.font_faces(routes), theme.css()]
  end

  # The hash of the content makes browsers fetch a changed stylesheet despite the year-long cache.
  defp stylesheet_url(site, routes) do
    hash = Base.encode16(:crypto.hash(:sha256, stylesheet(site, routes)), case: :lower)
    Routes.artifact_url(routes, "style.css") <> "?v=" <> binary_part(hash, 0, 12)
  end

  defp document_title(site_title, meta_title, is_home) do
    if is_home or meta_title == site_title,
      do: site_title,
      else: "#{meta_title} · #{site_title}"
  end

  defp sharing(routes, url, text, image, type \\ "website") do
    canonical = Routes.canonical(routes)

    %{
      canonical_url: url.(canonical),
      description: description(text),
      og_type: type,
      og_image_url:
        if(match?(%Image{}, image), do: Routes.image_url(canonical, image, :desktop_x1_jpg))
    }
  end

  defp description(text) do
    text = text |> String.replace(~r/\s+/u, " ") |> String.trim()

    if text == "", do: nil, else: ContentBlocks.truncate(text, @description_length)
  end

  defp first_image(data, content),
    do: content |> ContentBlocks.image_ids() |> Enum.find_value(&Map.get(data.images, &1))

  defp render(view, assigns) do
    theme = Themes.module(assigns.site)

    in_site_language(assigns.data, fn ->
      assigns
      |> Map.put(:inner_content, apply(theme, view, [assigns]))
      |> theme.layout()
      |> Safe.to_iodata()
      |> HTMLFormatter.format()
    end)
  end

  defp in_site_language(%SiteData{site: site}, fun),
    do: Gettext.with_locale(Feather.StaticSite.Gettext, site.language_code || "en", fun)

  defp projects_page(data),
    do: Enum.find(data.pages, &(&1.page_type == "projects" and not Page.homepage?(&1)))

  defp projects_trail(data, routes) do
    case projects_page(data) do
      nil -> []
      page -> [%{title: page.title, emoji: page.emoji, url: Routes.page_url(routes, page)}]
    end
  end

  defp blank?(value), do: not (is_binary(value) and String.trim(value) != "")
end
