defmodule Feather.StaticSite.Sitemap do
  @moduledoc """
  The sitemap (`sitemap.xml`): the home page, published posts, pages
  (except the homepage, which is the home page) and projects, addressed by
  the site's canonical URL, never a preview path.
  """

  alias Feather.Content.Page
  alias Feather.StaticSite.{Routes, SiteData, Xml}

  @doc "Renders the sitemap."
  @spec render(SiteData.t(), Routes.t()) :: iodata()
  def render(%SiteData{} = data, %Routes{} = routes) do
    routes = Routes.canonical(routes)

    entries =
      [{Routes.home_url(routes), home_lastmod(data)}] ++
        Enum.map(data.posts, &{Routes.post_url(routes, &1), &1.updated_at}) ++
        (data.pages
         |> Enum.reject(&Page.homepage?/1)
         |> Enum.map(&{Routes.page_url(routes, &1), &1.updated_at})) ++
        Enum.map(data.projects, &{Routes.project_url(routes, &1), &1.updated_at})

    urls =
      Enum.map(entries, fn {loc, lastmod} ->
        Xml.element(1, "url", [], [
          Xml.element(2, "loc", loc),
          Xml.element(2, "lastmod", iso8601(lastmod))
        ])
      end)

    [
      Xml.declaration(),
      Xml.element(0, "urlset", [{"xmlns", "http://www.sitemaps.org/schemas/sitemap/0.9"}], urls)
    ]
  end

  # The home page lists the published posts, so it changes with the most
  # recently changed one; the site's own timestamp does not move then.
  defp home_lastmod(%SiteData{site: site, posts: posts}) do
    Enum.max([site.updated_at | Enum.map(posts, & &1.updated_at)], DateTime)
  end

  defp iso8601(%DateTime{} = datetime) do
    datetime
    |> DateTime.shift_zone!("Etc/UTC")
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end
end
