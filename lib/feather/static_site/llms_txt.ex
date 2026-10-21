defmodule Feather.StaticSite.LlmsTxt do
  @moduledoc """
  The `llms.txt` of a site (llmstxt.org, ADR 0030): the site title as
  heading, the bio as summary when set, then sections for the pages (the
  homepage first), posts and projects. Each entry links its Markdown
  alternate (`Feather.StaticSite.MarkdownAlternate`) at the site's
  canonical URL under the alternate's title and carries the description
  its page gives in `<meta name="description">`
  (`Feather.StaticSite.ThemeHelpers.description/1`). Sections without
  entries are left out.
  """

  use Gettext, backend: Feather.StaticSite.Gettext

  alias Feather.Content.{Markdown, Page, Post, Project}
  alias Feather.StaticSite.{Routes, SiteData, ThemeHelpers}

  @doc "Renders the `llms.txt` of the site `data`."
  @spec render(SiteData.t(), Routes.t()) :: iodata()
  def render(%SiteData{site: site} = data, %Routes{} = routes) do
    routes = Routes.canonical(routes)

    [
      Markdown.heading(1, Markdown.escape(site.title)),
      "\n",
      summary(site.bio),
      section(gettext("Pages"), data.pages, data, routes),
      section(gettext("Posts"), data.posts, data, routes),
      section(gettext("Projects"), data.projects, data, routes)
    ]
  end

  defp summary(bio) do
    if ThemeHelpers.present?(bio), do: ["\n> ", Markdown.escape(bio), "\n"], else: []
  end

  defp section(_title, [], _data, _routes), do: []

  defp section(title, records, data, routes) do
    [
      "\n",
      Markdown.heading(2, Markdown.escape(title)),
      "\n\n",
      Enum.map(records, &entry(&1, data, routes))
    ]
  end

  defp entry(record, data, routes) do
    label = Markdown.escape(title(record, data))
    link = Markdown.link(label, Routes.markdown_url(routes, record))

    case ThemeHelpers.description(record) do
      nil -> ["- ", link, "\n"]
      description -> ["- ", link, ": ", Markdown.escape(description), "\n"]
    end
  end

  defp title(%Post{} = post, _data), do: ThemeHelpers.post_meta_title(post)
  defp title(%Page{} = page, data), do: ThemeHelpers.page_label(data.site, page)
  defp title(%Project{} = project, _data), do: project.title
end
