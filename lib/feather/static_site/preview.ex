defmodule Feather.StaticSite.Preview do
  @moduledoc """
  Live rendering of a site inside the CMS with the export's renderer and theme,
  addressed under `/preview/<site public id>/` (see
  `Feather.StaticSite.Routes.preview/1`). Shows the records as they are,
  unpublished changes and drafts included. Scheduled posts can be
  previewed by their address; the post list leaves them out. A path no
  content lives at follows the site's active redirect from it, if any.

  Access control is the caller's job: load the site with
  `Feather.Sites.get_site/2`.
  """

  alias Feather.Accounts.Scope
  alias Feather.{Diagrams, Media, Redirects}
  alias Feather.Fediverse.Pictures
  alias Feather.Media.Variants
  alias Feather.Sites.Site
  alias Feather.StaticSite.{GeneratedImages, ImageVariants, Renderer, Routes, SiteData, Themes}

  @type result ::
          {:html, iodata()}
          | {:content, String.t(), iodata()}
          | {:file, Path.t(), String.t()}
          | {:redirect, String.t()}
          | {:not_found, iodata()}

  @doc """
  Renders what lives at `path` (relative to the preview root, a string or
  path segments) of the site:

    * `{:html, iodata}` - a page
    * `{:content, content_type, iodata}` - `feed.xml`, `llms.txt`, `sitemap.xml`,
      `robots.txt`, `style.css`, the Markdown alternate of the home page, a
      post, page or project
    * `{:file, path, content_type}` - a stored image variant or one the
      image's roles need (generated then), a drawn favicon or share card,
      the picture of an approved reply's author, a font of the site's theme
      or a rendered diagram
    * `{:redirect, url}` - the preview URL an active redirect from the path
      leads to
    * `{:not_found, iodata}` - the site's 404 page
  """
  @spec render(Site.t(), String.t() | [String.t()]) :: result()
  def render(%Site{} = site, path) do
    routes = Routes.preview(site)

    case Routes.resolve(routes, path) do
      nil -> follow_redirect(site, routes, path)
      route -> serve(route, site, routes)
    end
  end

  defp follow_redirect(site, routes, path) do
    case Redirects.find_active_redirect(Scope.for_site(site), path) do
      nil -> not_found(site, routes)
      redirect -> {:redirect, Routes.path_url(routes, redirect.target)}
    end
  end

  # A missing variant is generated only if the image's roles need it.
  defp serve({:image, image, variant}, site, routes) do
    path = Media.variant_path(image, variant)

    if File.regular?(path) or
         (variant in ImageVariants.variants_of(site, image) and
            Media.ensure_variant(image, variant) == :ok) do
      {:file, path, Variants.content_type(variant)}
    else
      not_found(site, routes)
    end
  end

  defp serve({:font, name}, site, _routes) do
    theme = Themes.module(site)
    {:file, theme.font_path(name), Map.fetch!(theme.fonts(), name)}
  end

  defp serve({:generated_image, name}, site, routes),
    do: existing_file(GeneratedImages.path(name), "image/png", site, routes)

  defp serve({:reply_picture, name}, site, routes),
    do: existing_file(Pictures.path(name), "image/webp", site, routes)

  defp serve({:diagram, name}, site, routes),
    do: existing_file(Diagrams.path(name), "image/svg+xml", site, routes)

  defp serve(route, site, routes) do
    draw_favicon(site)
    render_route(route, load(site, route), routes)
  end

  # Share cards are left to the export: drafts would leave one behind for every title they had.
  defp draw_favicon(site) do
    case GeneratedImages.favicon(site) do
      nil -> :ok
      favicon -> GeneratedImages.ensure(favicon)
    end
  end

  defp existing_file(file, content_type, site, routes) do
    if File.regular?(file), do: {:file, file, content_type}, else: not_found(site, routes)
  end

  defp load(site, route) do
    data = SiteData.load(site, content: :current)
    if prerender?(route), do: SiteData.prerender(data, routed_records(route)), else: data
  end

  defp prerender?({:artifact, name}), do: name == "feed.xml"
  defp prerender?({:markdown, _record}), do: false
  defp prerender?(_route), do: true

  # A scheduled post is not among the data's posts, but its diagrams and code render too.
  defp routed_records({kind, record}) when kind in [:post, :page, :project], do: [record]
  defp routed_records(_route), do: []

  defp not_found(site, routes),
    do: {:not_found, Renderer.render_not_found(SiteData.load(site, content: :current), routes)}

  defp render_route({:home, page}, data, routes),
    do: {:html, Renderer.render_home(data, routes, page)}

  defp render_route({:post, post}, data, routes),
    do: {:html, Renderer.render_post(data, routes, SiteData.preload(post))}

  defp render_route({:page, page}, data, routes),
    do: {:html, Renderer.render_page(data, routes, SiteData.preload(page))}

  defp render_route({:project, project}, data, routes),
    do: {:html, Renderer.render_project(data, routes, SiteData.preload(project))}

  defp render_route({:markdown, :home}, data, routes),
    do: {:content, "text/markdown", Renderer.render_markdown(data, routes, :home)}

  defp render_route({:markdown, record}, data, routes) do
    {:content, "text/markdown", Renderer.render_markdown(data, routes, SiteData.preload(record))}
  end

  defp render_route({:artifact, name}, data, routes) do
    {:content, Renderer.artifact_content_type(name), Renderer.render_artifact(data, routes, name)}
  end
end
