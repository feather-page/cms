defmodule Feather.StaticSite.MetaTest do
  use Feather.DataCase

  alias Feather.{Content, Sites}
  alias Feather.StaticSite.{Export, RecordingSink, Routes}

  @day ~U[2025-01-01 10:00:00.000000Z]
  @long_text String.duplicate("Fish & \"chips\" by the sea. ", 12)

  setup do
    scope = site_scope_fixture(%{title: "Site", emoji: "🦉"})
    header = image_fixture(scope)
    picture = image_fixture(scope)

    post_fixture(scope, %{
      title: "Hello",
      slug: "/hello",
      header_image_id: header.id,
      publish_at: @day,
      content: [paragraph("<b>Bold</b> start. " <> @long_text)]
    })

    post_fixture(scope, %{
      title: "Pictures",
      slug: "/pictures",
      publish_at: DateTime.add(@day, 1, :day),
      content: [paragraph("Look."), image_block(picture)]
    })

    untitled =
      post_fixture(scope, %{
        title: nil,
        slug: nil,
        publish_at: DateTime.add(@day, 2, :day),
        content: [paragraph("Short note.")]
      })

    page_fixture(scope, %{title: "About", slug: "/about", content: [paragraph("About me.")]})

    project_fixture(scope, %{
      title: "Thing",
      slug: "/thing",
      short_description: "Builds <b>things</b>\nwell."
    })

    homepage = Content.get_homepage(scope)

    {:ok, homepage} =
      Content.update_page(scope, homepage, %{content: [paragraph("Welcome to my site.")]})

    {:ok, _} = Content.publish(scope, homepage)

    sink = RecordingSink.new(start_supervised!(RecordingSink))
    routes = Routes.new(scope.site, canonical_url: "https://example.com/")
    :ok = Export.run(Feather.Repo.reload!(scope.site), routes, sink)

    %{scope: scope, sink: sink, header: header, picture: picture, untitled: untitled}
  end

  defp doc(sink, path), do: sink |> RecordingSink.get(path) |> Floki.parse_document!()

  defp title(doc), do: doc |> Floki.find("title") |> Floki.text()

  defp meta(doc, key) do
    case Floki.attribute(doc, ~s(meta[name="#{key}"], meta[property="#{key}"]), "content") do
      [value] -> value
      [] -> nil
    end
  end

  defp canonical(doc),
    do: doc |> Floki.attribute(~s(link[rel="canonical"]), "href") |> List.first()

  test "the home page describes the site", c do
    home = doc(c.sink, "index.html")

    assert title(home) == "Site"
    assert meta(home, "description") == "Welcome to my site."
    assert canonical(home) == "https://example.com/"
    assert meta(home, "og:type") == "website"
    assert meta(home, "og:title") == "Site"
    assert meta(home, "og:url") == "https://example.com/"
    assert meta(home, "og:site_name") == "Site"
    assert meta(home, "og:locale") == "en_US"
    assert meta(home, "og:image") == nil
    assert meta(home, "twitter:card") == nil

    assert Floki.attribute(home, ~s(link[rel="alternate"][type="application/rss+xml"]), "href") ==
             ["/feed.xml"]
  end

  test "a post is an article with a plain text excerpt and its header image", c do
    post = doc(c.sink, "hello/index.html")
    description = meta(post, "description")

    assert title(post) == "Hello · Site"
    assert description =~ ~r/\ABold start\. Fish & "chips" by the sea\./
    assert String.length(description) <= 155
    assert String.ends_with?(description, "…")
    refute description =~ "<"
    assert canonical(post) == "https://example.com/hello/"
    assert meta(post, "og:type") == "article"
    assert meta(post, "og:title") == "Hello"
    assert meta(post, "og:description") == description
    assert meta(post, "og:url") == "https://example.com/hello/"

    assert meta(post, "og:image") ==
             "https://example.com/images/#{c.header.public_id}/desktop_x1.jpg"

    assert meta(post, "twitter:card") == "summary_large_image"
  end

  test "without a header image the first content image is shared", c do
    post = doc(c.sink, "pictures/index.html")

    assert meta(post, "og:image") ==
             "https://example.com/images/#{c.picture.public_id}/desktop_x1.jpg"
  end

  test "an untitled post is titled by the site alone", c do
    post = doc(c.sink, "posts/#{String.downcase(c.untitled.public_id)}/index.html")

    assert title(post) == "Site"
    assert meta(post, "description") == "Short note."
  end

  test "pages and projects are described by their content and summary", c do
    page = doc(c.sink, "about/index.html")
    assert title(page) == "About · Site"
    assert meta(page, "description") == "About me."
    assert meta(page, "og:type") == "website"
    assert canonical(page) == "https://example.com/about/"

    project = doc(c.sink, "projects/thing/index.html")
    assert title(project) == "Thing · Site"
    assert meta(project, "description") == "Builds things well."
    assert canonical(project) == "https://example.com/projects/thing/"
  end

  test "the not found page has no canonical address", c do
    not_found = doc(c.sink, "404.html")

    assert title(not_found) == "Page not found · Site"
    assert canonical(not_found) == nil
    assert meta(not_found, "og:url") == nil
    assert meta(not_found, "robots") == "noindex"
    assert meta(doc(c.sink, "index.html"), "robots") == nil
  end

  test "titles and descriptions are escaped in the head", c do
    post_fixture(c.scope, %{
      title: ~s(Say "hi" <now>),
      slug: "/say",
      content: [paragraph(~s(Quote "this" &lt;tag&gt; here.))]
    })

    sink = RecordingSink.new(start_supervised!(RecordingSink, id: :escaping))
    site = Feather.Repo.reload!(c.scope.site)
    :ok = Export.run(site, Routes.new(site, canonical_url: "https://example.com/"), sink)
    html = RecordingSink.get(sink, "say/index.html")

    title = "Say &quot;hi&quot; &lt;now&gt;"
    description = "Quote &quot;this&quot; &lt;tag&gt; here."

    assert html =~ "<title>#{title} · Site</title>"
    assert html =~ ~s(<meta property="og:title" content="#{title}" />)
    assert html =~ ~s(<meta name="description" content="#{description}" />)
    assert html =~ ~s(<meta property="og:description" content="#{description}" />)
  end

  test "og:locale follows the site language", c do
    {:ok, site} = Sites.update_site(c.scope, c.scope.site, %{language_code: "de"})
    sink = RecordingSink.new(start_supervised!(RecordingSink, id: :german))
    :ok = Export.run(site, Routes.new(site, canonical_url: "https://example.com/"), sink)

    assert sink |> doc("index.html") |> meta("og:locale") == "de_DE"
  end
end
