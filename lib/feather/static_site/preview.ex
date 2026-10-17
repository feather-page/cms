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

  alias Feather.Media
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
    * `{:content, content_type, iodata}` - `feed.xml`, `sitemap.xml`, `robots.txt`
    * `{:file, path, content_type}` - an image variant or a font of the site's theme
    * `{:not_found, iodata}` - the site's 404 page
  """
  @spec render(Site.t(), String.t() | [String.t()]) :: result()
  def render(%Site{} = site, path) do
    routes = Routes.preview(site)

    case Routes.resolve(routes, path) do
      nil ->
        not_found(site, routes)

      {:image, image, variant} ->
        file = Media.variant_path(image, variant.name)

        if File.regular?(file),
          do: {:file, file, Variants.content_type(variant)},
          else: not_found(site, routes)

      {:font, name} ->
        theme = Themes.module(site)
        {:file, theme.font_path(name), Map.fetch!(theme.fonts(), name)}

      route ->
        render_route(route, load(site), routes)
    end
  end

  defp load(site), do: SiteData.load(site, content: :current)

  defp not_found(site, routes), do: {:not_found, Renderer.render_not_found(load(site), routes)}

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
