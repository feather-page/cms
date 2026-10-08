defmodule Feather.StaticSite.Feed do
  @moduledoc """
  The RSS 2.0 feed (`feed.xml`): the 20 latest published posts with their
  rendered content, addressed by the site's canonical URL.
  """

  alias Feather.StaticSite.{Blocks, Routes, SiteData, Xml}

  @max_items 20

  @doc """
  Renders the feed. `block_context` renders the post content (it should
  use canonical routes so links in feed readers work).
  """
  @spec render(SiteData.t(), Routes.t(), Blocks.context()) :: iodata()
  def render(%SiteData{site: site, posts: posts}, %Routes{} = routes, block_context) do
    routes = Routes.canonical(routes)

    channel =
      [
        Xml.element(2, "title", site.title),
        Xml.element(2, "link", Routes.home_url(routes)),
        Xml.element(2, "description", "#{site.title} - RSS Feed"),
        Xml.element(2, "language", site.language_code),
        Xml.element(
          2,
          "atom:link",
          [
            {"href", Routes.artifact_url(routes, "feed.xml")},
            {"rel", "self"},
            {"type", "application/rss+xml"}
          ],
          nil
        )
      ] ++ Enum.map(Enum.take(posts, @max_items), &item(&1, routes, block_context))

    [
      Xml.declaration(),
      Xml.element(
        0,
        "rss",
        [{"version", "2.0"}, {"xmlns:atom", "http://www.w3.org/2005/Atom"}],
        [Xml.element(1, "channel", [], channel)]
      )
    ]
  end

  defp item(post, routes, block_context) do
    url = Routes.post_url(routes, post)

    title =
      if is_binary(post.title) and String.trim(post.title) != "", do: post.title, else: "Post"

    Xml.element(3, "item", [], [
      Xml.element(4, "title", title),
      Xml.element(4, "link", url),
      Xml.element(4, "pubDate", rfc2822(post.publish_at)),
      Xml.element(4, "guid", [{"isPermaLink", "true"}], url),
      Xml.element(4, "description", Blocks.to_html(post.content, block_context))
    ])
  end

  @doc ~S'A UTC datetime in RFC 2822 format: `"Tue, 06 Oct 2026 12:00:00 +0000"`.'
  @spec rfc2822(DateTime.t()) :: String.t()
  def rfc2822(%DateTime{} = datetime) do
    datetime
    |> DateTime.shift_zone!("Etc/UTC")
    |> Calendar.strftime("%a, %d %b %Y %H:%M:%S +0000")
  end
end
