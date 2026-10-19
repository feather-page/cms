defmodule Feather.StaticSite.Preview do
  @moduledoc """
  Live rendering of a site inside the CMS with the export's renderer and theme,
  addressed under `/preview/<site public id>/` (see
  `Feather.StaticSite.Routes.preview/1`). Shows the records as they are,
  unpublished changes and drafts included. Scheduled posts can be
  previewed by their address; the post list leaves them out.

  Access control is the caller's job: load the site with
  `Feather.Sites.get_site/2`.
  """

  alias Feather.{Diagrams, Media}
  alias Feather.Media.Variants
  alias Feather.Sites.Site
  alias Feather.StaticSite.{Renderer, Routes, SiteData, Themes}

  @type result ::
          {:html, iodata()}
          | {:content, String.t(), iodata()}
          | {:file, Path.t(), String.t()}
          | {:not_found, iodata()}

  @doc """
  Renders what lives at `path` (relative to the preview root, a string or
  path segments) of the site:

    * `{:html, iodata}` - a page
    * `{:content, content_type, iodata}` - `feed.xml`, `sitemap.xml`, `robots.txt`,
      `style.css`
    * `{:file, path, content_type}` - an image variant, a font of the site's
      theme or a rendered diagram
    * `{:not_found, iodata}` - the site's 404 page
  """
  @spec render(Site.t(), String.t() | [String.t()]) :: result()
  def render(%Site{} = site, path) do
    routes = Routes.preview(site)
    routes |> Routes.resolve(path) |> serve(site, routes)
  end

  defp serve(nil, site, routes), do: not_found(site, routes)

  defp serve({:image, image, variant}, site, routes) do
    file = Media.variant_path(image, variant.name)
    existing_file(file, Variants.content_type(variant), site, routes)
  end

  defp serve({:font, name}, site, _routes) do
    theme = Themes.module(site)
    {:file, theme.font_path(name), Map.fetch!(theme.fonts(), name)}
  end

  defp serve({:diagram, name}, site, routes),
    do: existing_file(Diagrams.path(name), "image/svg+xml", site, routes)

  defp serve(route, site, routes), do: render_route(route, load(site, route), routes)

  defp existing_file(file, content_type, site, routes) do
    if File.regular?(file), do: {:file, file, content_type}, else: not_found(site, routes)
  end

  defp load(site, route) do
    data = SiteData.load(site, content: :current)
    if prerender?(route), do: SiteData.prerender(data, routed_records(route)), else: data
  end

  defp prerender?({:artifact, name}), do: name == "feed.xml"
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

  defp render_route({:artifact, name}, data, routes) do
    {:content, Renderer.artifact_content_type(name), Renderer.render_artifact(data, routes, name)}
  end
end
