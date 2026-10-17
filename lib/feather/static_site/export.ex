defmodule Feather.StaticSite.Export do
  @moduledoc """
  Renders a whole site into a sink: the pages of the post list, the posts
  that are due, projects, pages (the homepage is the first page of the post
  list), the image variants in use, the fonts of the site's theme, the
  rendered diagrams, `feed.xml`, `robots.txt`, `sitemap.xml` and
  `404.html`.

  Knows nothing about deployment targets, locks or where the files end up
  (see ADR 0006). The data is loaded up front; rendering and copying run
  in parallel with bounded concurrency. Diagrams are rendered up front
  too; one that fails shows its source and does not fail the export.
  """

  alias Feather.Content.Page
  alias Feather.{Diagrams, Media}
  alias Feather.Media.Variants
  alias Feather.Sites.Site
  alias Feather.StaticSite.{Renderer, Routes, Sink, SiteData, Themes}

  require Logger

  @doc """
  Exports the site into the sink.

  ## Options

    * `:content` - `:published` (the default) or `:current`, see
      `Feather.StaticSite.SiteData.load/2`
    * `:now` - the time that decides which posts are due (default: now)
    * `:max_concurrency` - parallel renders and copies (default: number of schedulers)
  """
  @spec run(Site.t(), Routes.t(), Sink.t(), keyword()) :: :ok
  def run(%Site{} = site, %Routes{} = routes, sink, opts \\ []) do
    data =
      site |> SiteData.load(Keyword.take(opts, [:content, :now])) |> SiteData.render_diagrams()

    images = SiteData.images_in_use(data)
    theme = Themes.module(site)

    jobs =
      Enum.map(1..Renderer.total_pages(data), &{:home, &1}) ++
        Enum.map(data.posts, &{:post, &1}) ++
        Enum.map(data.projects, &{:project, &1}) ++
        (data.pages |> Enum.reject(&Page.homepage?/1) |> Enum.map(&{:page, &1})) ++
        Enum.map(~w(feed.xml robots.txt sitemap.xml), &{:artifact, &1}) ++
        [:not_found] ++
        (theme.fonts() |> Map.keys() |> Enum.sort() |> Enum.map(&{:font, theme, &1})) ++
        (data.diagrams |> Map.values() |> Enum.map(&{:diagram, &1})) ++
        for(image <- images, variant <- Variants.all(), do: {:image, image, variant})

    # A crashing task would take the caller down with it (tasks are
    # linked), so failures are caught in the task and raised here, where
    # the caller can handle them.
    jobs
    |> Task.async_stream(&safely_run_job(&1, data, routes, sink),
      max_concurrency: Keyword.get(opts, :max_concurrency, System.schedulers_online()),
      timeout: :infinity,
      ordered: false
    )
    |> Enum.find_value(fn
      {:ok, :ok} -> nil
      {:ok, {:error, message}} -> message
    end)
    |> case do
      nil -> :ok
      message -> raise RuntimeError, "static export failed: " <> message
    end
  end

  defp safely_run_job(job, data, routes, sink) do
    run_job(job, data, routes, sink)
    :ok
  rescue
    exception -> {:error, "#{describe(job)}: #{Exception.message(exception)}"}
  end

  defp describe(:not_found), do: "404 page"
  defp describe({:image, image, variant}), do: "image #{image.public_id} #{variant.filename}"
  defp describe({kind, %{public_id: public_id}}), do: "#{kind} #{public_id}"
  defp describe({:font, _theme, name}), do: "font #{name}"
  defp describe({kind, name}), do: "#{kind} #{name}"

  defp run_job({:home, page}, data, routes, sink),
    do: Sink.write(sink, Routes.home_path(routes, page), Renderer.render_home(data, routes, page))

  defp run_job({:post, post}, data, routes, sink),
    do: Sink.write(sink, Routes.post_path(routes, post), Renderer.render_post(data, routes, post))

  defp run_job({:project, project}, data, routes, sink) do
    Sink.write(
      sink,
      Routes.project_path(routes, project),
      Renderer.render_project(data, routes, project)
    )
  end

  defp run_job({:page, page}, data, routes, sink),
    do: Sink.write(sink, Routes.page_path(routes, page), Renderer.render_page(data, routes, page))

  defp run_job(:not_found, data, routes, sink),
    do: Sink.write(sink, Routes.not_found_path(routes), Renderer.render_not_found(data, routes))

  defp run_job({:artifact, name}, data, routes, sink) do
    Sink.write(
      sink,
      Routes.artifact_path(routes, name),
      Renderer.render_artifact(data, routes, name)
    )
  end

  defp run_job({:font, theme, name}, _data, routes, sink),
    do: Sink.copy(sink, Routes.font_path(routes, name), from: theme.font_path(name))

  defp run_job({:diagram, name}, _data, routes, sink),
    do: Sink.copy(sink, Routes.diagram_path(routes, name), from: Diagrams.path(name))

  defp run_job({:image, image, variant}, _data, routes, sink) do
    source = Media.variant_path(image, variant.name)

    if File.regular?(source) do
      Sink.copy(sink, Routes.image_path(routes, image, variant.name), from: source)
    else
      Logger.warning("Image variant missing, not exported: #{source}")
    end
  end
end
