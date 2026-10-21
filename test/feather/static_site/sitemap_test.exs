defmodule Feather.StaticSite.SitemapTest do
  use Feather.DataCase

  alias Feather.Content
  alias Feather.StaticSite.{Export, RecordingSink, Routes}

  setup do
    %{scope: site_scope_fixture()}
  end

  defp published_on(record, at) do
    %{published_version: %schema{id: id}} = Content.preload_published_version(record)
    Repo.update_all(from(v in schema, where: v.id == ^id), set: [published_at: at])
    record
  end

  defp sitemap(scope) do
    sink = RecordingSink.new(start_supervised!(RecordingSink))
    routes = Routes.new(scope.site, canonical_url: "https://example.com/")
    :ok = Export.run(Repo.reload!(scope.site), routes, sink)
    RecordingSink.get(sink, "sitemap.xml")
  end

  defp lastmod(xml, path) do
    url = "https://example.com/" <> path

    [_, lastmod] =
      Regex.run(~r{<loc>#{Regex.escape(url)}</loc>\s*<lastmod>([^<]+)</lastmod>}, xml) ||
        flunk("#{url} missing from #{xml}")

    lastmod
  end

  test "unpublished changes do not move lastmod", %{scope: scope} do
    post =
      scope
      |> post_fixture(%{slug: "/hello", publish_at: ~U[2026-09-30 08:00:00.000000Z]})
      |> published_on(~U[2026-10-01 09:00:00.000000Z])

    {:ok, _} = Content.update_post(scope, post, %{title: "Edited"})

    assert scope |> sitemap() |> lastmod("hello/") == "2026-10-01T09:00:00Z"
  end

  test "a scheduled post is dated by its publish date", %{scope: scope} do
    scope
    |> post_fixture(%{slug: "/later", publish_at: ~U[2026-10-10 07:00:00.000000Z]})
    |> published_on(~U[2026-10-01 09:00:00.000000Z])

    assert scope |> sitemap() |> lastmod("later/") == "2026-10-10T07:00:00Z"
  end

  test "pages and projects are dated by their published versions", %{scope: scope} do
    page = page_fixture(scope, %{slug: "/about"})
    published_on(page, ~U[2026-10-02 09:00:00.000000Z])
    {:ok, _} = Content.update_page(scope, page, %{title: "Edited"})

    project = project_fixture(scope, %{slug: "/thing"})
    published_on(project, ~U[2026-10-03 09:00:00.000000Z])
    {:ok, _} = Content.update_project(scope, project, %{title: "Edited"})

    xml = sitemap(scope)
    assert lastmod(xml, "about/") == "2026-10-02T09:00:00Z"
    assert lastmod(xml, "projects/thing/") == "2026-10-03T09:00:00Z"
  end

  test "the home page is dated by its most recently changed post", %{scope: scope} do
    Repo.update_all(from(s in Feather.Sites.Site, where: s.id == ^scope.site.id),
      set: [updated_at: ~U[2026-09-01 00:00:00.000000Z]]
    )

    post =
      scope
      |> post_fixture(%{slug: "/hello", publish_at: ~U[2026-09-30 08:00:00.000000Z]})
      |> published_on(~U[2026-10-01 09:00:00.000000Z])

    {:ok, _} = Content.update_post(scope, post, %{title: "Edited"})

    assert scope |> sitemap() |> lastmod("") == "2026-10-01T09:00:00Z"
  end
end
