defmodule Feather.StaticSite.Renderer do
  @moduledoc """
  Renders the pages and files of a static site from `SiteData` and
  `Routes`. Used by the export and the preview alike, so both show the
  same markup. Every function returns iodata and touches no database.
  """

  alias Feather.Content.{Page, Post, Project}
  alias Feather.StaticSite.{Blocks, Feed, Routes, SiteData, Sitemap, Templates}

  @posts_per_page 25

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
    posts = Enum.slice(data.posts, (page_number - 1) * @posts_per_page, @posts_per_page)

    assigns =
      base_assigns(data, routes, data.site.title, data.site.emoji, true)
      |> Map.merge(%{
        rss_url: Routes.artifact_url(routes, "feed.xml"),
        posts: posts,
        current_page: page_number,
        total_pages: total_pages(data)
      })

    render(&Templates.home/1, assigns)
  end

  @doc "A post (its book, header and thumbnail image preloaded)."
  @spec render_post(SiteData.t(), Routes.t(), Post.t()) :: iodata()
  def render_post(%SiteData{} = data, %Routes{} = routes, %Post{} = post) do
    title = if blank?(post.title), do: data.site.title, else: post.title

    assigns =
      data
      |> base_assigns(routes, title, post.emoji, false)
      |> Map.merge(%{post: post, header_image: post.header_image})

    render(&Templates.post/1, assigns)
  end

  @doc "A page (its header image preloaded)."
  @spec render_page(SiteData.t(), Routes.t(), Page.t()) :: iodata()
  def render_page(%SiteData{} = data, %Routes{} = routes, %Page{} = page) do
    assigns =
      data
      |> base_assigns(routes, page.title, page.emoji, false)
      |> Map.merge(%{page: page, header_image: page.header_image})

    render(&Templates.page/1, assigns)
  end

  @doc "A project (its header and thumbnail image preloaded)."
  @spec render_project(SiteData.t(), Routes.t(), Project.t()) :: iodata()
  def render_project(%SiteData{} = data, %Routes{} = routes, %Project{} = project) do
    assigns =
      data
      |> base_assigns(routes, project.title, project.emoji, false)
      |> Map.merge(%{project: project, header_image: project.header_image})

    render(&Templates.project/1, assigns)
  end

  @doc """
  A generated file at the site root: `feed.xml`, `sitemap.xml` or
  `robots.txt`.
  """
  @spec render_artifact(SiteData.t(), Routes.t(), String.t()) :: iodata()
  def render_artifact(%SiteData{} = data, %Routes{} = routes, "feed.xml"),
    do: Feed.render(data, routes, block_context(data, Routes.canonical(routes)))

  def render_artifact(%SiteData{} = data, %Routes{} = routes, "sitemap.xml"),
    do: Sitemap.render(data, routes)

  def render_artifact(%SiteData{}, %Routes{} = routes, "robots.txt") do
    sitemap = routes |> Routes.canonical() |> Routes.artifact_url("sitemap.xml")
    "User-agent: *\nAllow: /\n\nSitemap: #{sitemap}\n"
  end

  @doc "The content type of a generated file at the site root."
  @spec artifact_content_type(String.t()) :: String.t()
  def artifact_content_type("feed.xml"), do: "application/rss+xml"
  def artifact_content_type("sitemap.xml"), do: "application/xml"
  def artifact_content_type("robots.txt"), do: "text/plain"

  @doc "The context for rendering blocks of the site."
  @spec block_context(SiteData.t(), Routes.t()) :: Blocks.context()
  def block_context(%SiteData{} = data, %Routes{} = routes),
    do: Blocks.context(routes, data.images, data.books_by_public_id)

  defp base_assigns(data, routes, page_title, page_emoji, is_home) do
    %{
      data: data,
      site: data.site,
      routes: routes,
      ctx: block_context(data, routes),
      social_links: data.social_links,
      page_title: page_title,
      page_emoji: if(blank?(page_emoji), do: nil, else: page_emoji),
      is_home: is_home,
      header_image: nil,
      rss_url: nil,
      __changed__: nil
    }
  end

  defp render(view, assigns) do
    assigns
    |> Map.put(:inner_content, view.(assigns))
    |> Templates.layout()
    |> Phoenix.HTML.Safe.to_iodata()
  end

  defp blank?(value), do: not (is_binary(value) and String.trim(value) != "")
end
