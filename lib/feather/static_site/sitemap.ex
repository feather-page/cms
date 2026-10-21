defmodule Feather.StaticSite.Sitemap do
  @moduledoc """
  The sitemap (`sitemap.xml`): the home page, published posts, pages
  (except the homepage, which is the home page) and projects, addressed by
  the site's canonical URL, never a preview path. Each is dated by when it
  last changed on the site (`Feather.Content.last_changed_at/1`), so
  unpublished changes do not move its `lastmod`.
  """

  alias Feather.Content
  alias Feather.Content.Page
  alias Feather.StaticSite.{Routes, SiteData, Xml}

  @doc "Renders the sitemap."
  @spec render(SiteData.t(), Routes.t()) :: iodata()
  def render(%SiteData{} = data, %Routes{} = routes) do
    urls = data |> entries(Routes.canonical(routes)) |> Enum.map(&url_element/1)

    [
      Xml.declaration(),
      Xml.element(0, "urlset", [{"xmlns", "http://www.sitemaps.org/schemas/sitemap/0.9"}], urls)
    ]
  end

  defp entries(data, routes) do
    [{Routes.home_url(routes), home_lastmod(data)}] ++
      Enum.map(data.posts, &{Routes.post_url(routes, &1), changed_at(&1)}) ++
      (data.pages
       |> Enum.reject(&Page.homepage?/1)
       |> Enum.map(&{Routes.page_url(routes, &1), changed_at(&1)})) ++
      Enum.map(data.projects, &{Routes.project_url(routes, &1), changed_at(&1)})
  end

  defp url_element({loc, lastmod}) do
    Xml.element(1, "url", [], [
      Xml.element(2, "loc", loc),
      Xml.element(2, "lastmod", iso8601(lastmod))
    ])
  end

  # The home page lists the published posts, so it changes with the most
  # recently changed one; the site's own timestamp does not move then.
  defp home_lastmod(%SiteData{site: site, posts: posts}) do
    Enum.max([site.updated_at | Enum.map(posts, &changed_at/1)], DateTime)
  end

  # The preview also lists drafts, which have no published version.
  defp changed_at(record), do: Content.last_changed_at(record) || record.updated_at

  defp iso8601(%DateTime{} = datetime) do
    datetime
    |> DateTime.shift_zone!("Etc/UTC")
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end
end
