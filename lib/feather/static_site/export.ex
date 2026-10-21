defmodule Feather.StaticSite.Export do
  @moduledoc """
  Renders the published versions of a whole site into a sink: the pages
  of the post list, the posts that are due, projects, pages (the homepage
  is the first page of the post list), the variants of the images in use
  that their roles need in the theme (`Feather.StaticSite.ImageVariants`,
  missing ones are generated first), the favicon and share cards the pages
  link (`Feather.StaticSite.GeneratedImages`, drawn first), the fonts of
  the site's theme, the rendered diagrams, `feed.xml`, `robots.txt`,
  `sitemap.xml`, `style.css`, `404.html`, the IndexNow key file (ADR 0027)
  and the `.htaccess` for Apache hosts, with the security headers and the
  active redirects.

  Knows nothing about deployment targets, locks or where the files end up
  (see ADR 0006). The data is loaded up front; rendering and copying run
  in parallel with bounded concurrency. Diagrams are rendered up front
  too; one that fails shows its source and does not fail the export.
  """

  alias Feather.Content.{Page, Slug}
  alias Feather.{Diagrams, Media}
  alias Feather.Sites.Site

  alias Feather.StaticSite.{
    GeneratedImages,
    Htaccess,
    ImageVariants,
    Renderer,
    Routes,
    Sink,
    SiteData,
    Themes
  }

  require Logger

  @doc """
  Exports the site into the sink.

  ## Options

    * `:now` - the time that decides which posts are due (default: now)
    * `:max_concurrency` - parallel renders and copies (default: number of schedulers)
  """
  @spec run(Site.t(), Routes.t(), Sink.t(), keyword()) :: :ok
  def run(%Site{} = site, %Routes{} = routes, sink, opts \\ []) do
    data = site |> SiteData.load(Keyword.take(opts, [:now])) |> SiteData.prerender()
    redirects = SiteData.redirects(data)
    documents = documents(data)

    jobs =
      [:not_found, {:htaccess, redirects} | documents] ++
        indexnow_key_jobs(site) ++
        Enum.map(Slug.artifacts(), &{:artifact, &1}) ++
        asset_jobs(data, site) ++ generated_image_jobs(data, routes, documents)

    run_jobs(jobs, data, routes, sink, opts)
  end

  defp documents(data) do
    Enum.map(1..Renderer.total_pages(data), &{:home, &1}) ++
      Enum.map(data.posts, &{:post, &1}) ++
      Enum.map(data.projects, &{:project, &1}) ++
      (data.pages |> Enum.reject(&Page.homepage?/1) |> Enum.map(&{:page, &1}))
  end

  defp indexnow_key_jobs(%Site{indexnow_key: nil}), do: []
  defp indexnow_key_jobs(%Site{indexnow_key: key}), do: [{:indexnow_key, key}]

  defp generated_image_jobs(data, routes, documents) do
    documents
    |> Enum.flat_map(&Renderer.generated_images(data, routes, &1))
    |> Enum.uniq_by(&GeneratedImages.file_name/1)
    |> Enum.map(&{:generated_image, &1})
  end

  defp asset_jobs(data, site) do
    theme = Themes.module(site)
    fonts = theme.fonts() |> Map.keys() |> Enum.sort()
    roles = ImageVariants.image_roles(site)

    Enum.map(fonts, &{:font, theme, &1}) ++
      Enum.map(Map.values(data.diagrams), &{:diagram, &1}) ++
      for image <- SiteData.images_in_use(data),
          variant <- ImageVariants.variants(site, image, Map.get(roles, image.id, [])),
          do: {:image, image, variant}
  end

  # A crashing (linked) task would take the caller down, so failures are raised here instead.
  defp run_jobs(jobs, data, routes, sink, opts) do
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
    |> raise_if_failed()
  end

  defp raise_if_failed(nil), do: :ok
  defp raise_if_failed(message), do: raise(RuntimeError, "static export failed: " <> message)

  defp safely_run_job(job, data, routes, sink) do
    run_job(job, data, routes, sink)
    :ok
  rescue
    exception -> {:error, "#{describe(job)}: #{Exception.message(exception)}"}
  end

  defp describe(:not_found), do: "404 page"
  defp describe({:htaccess, _redirects}), do: ".htaccess"
  defp describe({:indexnow_key, _key}), do: "IndexNow key file"
  defp describe({:image, image, variant}), do: "image #{image.public_id} #{variant.filename}"

  defp describe({:generated_image, image}),
    do: "generated image #{GeneratedImages.file_name(image)}"

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

  defp run_job({:htaccess, redirects}, _data, routes, sink),
    do: Sink.write(sink, Routes.htaccess_path(routes), Htaccess.render(routes, redirects))

  defp run_job({:indexnow_key, key}, _data, routes, sink),
    do: Sink.write(sink, Routes.indexnow_key_path(routes), key)

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
    case Media.ensure_variant(image, variant) do
      :ok ->
        source = Media.variant_path(image, variant)
        Sink.copy(sink, Routes.image_path(routes, image, variant), from: source)

      {:error, reason} ->
        Logger.warning(
          "Image variant #{image.public_id}/#{variant.filename} missing, not exported: #{inspect(reason)}"
        )
    end
  end

  defp run_job({:generated_image, image}, _data, routes, sink) do
    name = GeneratedImages.file_name(image)

    case GeneratedImages.ensure(image) do
      :ok ->
        Sink.copy(sink, Routes.generated_image_path(routes, name),
          from: GeneratedImages.path(name)
        )

      {:error, reason} ->
        Logger.warning(
          "Generated image #{name} could not be drawn, not exported: #{inspect(reason)}"
        )
    end
  end
end
