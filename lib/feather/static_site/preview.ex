defmodule Feather.StaticSite.Preview do
  @moduledoc """
  Live rendering of a site inside the CMS with the export's templates,
  addressed under `/preview/<target public id>/` (see
  `Feather.StaticSite.Routes`). Shows the records as they are, unpublished
  changes and drafts included, like a staging export. Scheduled posts can
  be previewed by their address; the post list leaves them out.

  Access control is the caller's job: load the target with
  `Feather.Publishing.get_preview_target/2`.
  """

  alias Feather.Media
  alias Feather.Media.Variants
  alias Feather.Publishing.DeploymentTarget
  alias Feather.Sites.Site
  alias Feather.StaticSite.{Renderer, Routes, SiteData}

  @type result ::
          {:html, iodata()}
          | {:content, String.t(), iodata()}
          | {:file, Path.t(), String.t()}
          | :not_found

  @doc """
  Renders what lives at `path` (relative to the preview root, a string or
  path segments) of the target's site (preloaded on the target):

    * `{:html, iodata}` - a page
    * `{:content, content_type, iodata}` - `feed.xml`, `sitemap.xml`, `robots.txt`
    * `{:file, path, content_type}` - an image variant
    * `:not_found`
  """
  @spec render(DeploymentTarget.t(), String.t() | [String.t()]) :: result()
  def render(%DeploymentTarget{site: %Site{} = site} = target, path) do
    routes = Routes.for(target, :preview)

    case Routes.resolve(routes, path) do
      nil ->
        :not_found

      {:image, image, variant} ->
        file = Media.variant_path(image, variant.name)

        if File.regular?(file),
          do: {:file, file, Variants.content_type(variant)},
          else: :not_found

      route ->
        render_route(route, SiteData.load(site, content: :current), routes)
    end
  end

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
