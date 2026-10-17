defmodule Feather.StaticSite.Preview do
  @moduledoc """
  Live rendering of a site inside the CMS with the export's renderer and theme,
  addressed under `/preview/<target public id>/` (see
  `Feather.StaticSite.Routes`). Shows the records as they are, unpublished
  changes and drafts included, like a staging export. Scheduled posts can
  be previewed by their address; the post list leaves them out.

  Access control is the caller's job: load the target with
  `Feather.Publishing.get_preview_target/2`.
  """

  alias Feather.{Diagrams, Media}
  alias Feather.Media.Variants
  alias Feather.Publishing.DeploymentTarget
  alias Feather.Sites.Site
  alias Feather.StaticSite.{Renderer, Routes, SiteData, Themes}

  @type result ::
          {:html, iodata()}
          | {:content, String.t(), iodata()}
          | {:file, Path.t(), String.t()}
          | {:not_found, iodata()}

  @doc """
  Renders what lives at `path` (relative to the preview root, a string or
  path segments) of the target's site (preloaded on the target):

    * `{:html, iodata}` - a page
    * `{:content, content_type, iodata}` - `feed.xml`, `sitemap.xml`, `robots.txt`
    * `{:file, path, content_type}` - an image variant, a font of the site's
      theme or a rendered diagram
    * `{:not_found, iodata}` - the site's 404 page
  """
  @spec render(DeploymentTarget.t(), String.t() | [String.t()]) :: result()
  def render(%DeploymentTarget{site: %Site{} = site} = target, path) do
    routes = Routes.for(target, :preview)

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

      {:diagram, name} ->
        file = Diagrams.path(name)
        if File.regular?(file), do: {:file, file, "image/svg+xml"}, else: not_found(site, routes)

      route ->
        render_route(route, load(site, route), routes)
    end
  end

  defp load(site, route) do
    data = SiteData.load(site, content: :current)
    if diagrams?(route), do: SiteData.render_diagrams(data, routed_records(route)), else: data
  end

  defp diagrams?({:artifact, name}), do: name == "feed.xml"
  defp diagrams?(_route), do: true

  # A scheduled post is not among the data's posts, but its diagrams render too.
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
