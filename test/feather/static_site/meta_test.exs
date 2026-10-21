defmodule Feather.StaticSite.MetaTest do
  use Feather.DataCase

  alias Feather.{Books, Content, Sites}
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
    assert meta(home, "og:image") =~ ~r"\Ahttps://example\.com/images/[0-9a-f]{64}\.png\z"
    assert meta(home, "twitter:card") == "summary_large_image"

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
             "https://example.com/images/#{c.header.public_id}/1200.jpg"

    assert meta(post, "twitter:card") == "summary_large_image"
  end

  test "without a header image the first content image is shared", c do
    post = doc(c.sink, "pictures/index.html")

    assert meta(post, "og:image") ==
             "https://example.com/images/#{c.picture.public_id}/1200.jpg"
  end

  test "an untitled post is titled by its first words", c do
    post = doc(c.sink, "posts/#{String.downcase(c.untitled.public_id)}/index.html")

    assert title(post) == "Short note. · Site"
    assert meta(post, "og:title") == "Short note."
    assert meta(post, "description") == "Short note."
  end

  test "an untitled review is titled by its book", c do
    book = book_fixture(c.scope, %{title: "Dune", read_at: ~D[2025-02-01]})

    {:ok, %{post: review}} =
      Books.create_review(c.scope, book, %{slug: "/dune", content: [paragraph("Loved it.")]})

    {:ok, _} = Content.publish(c.scope, review)

    sink = RecordingSink.new(start_supervised!(RecordingSink, id: :review))
    :ok = Export.run(c.scope.site, Routes.new(c.scope.site), sink)
    post = doc(sink, "dune/index.html")

    assert title(post) == "Dune · Site"
    assert meta(post, "og:title") == "Dune"
  end

  test "an untitled post without text is titled by its date in the site language", c do
    {:ok, site} = Sites.update_site(c.scope, c.scope.site, %{language_code: "de"})
    empty = post_fixture(c.scope, %{title: nil, slug: nil, content: [], publish_at: @day})

    sink = RecordingSink.new(start_supervised!(RecordingSink, id: :textless))
    :ok = Export.run(site, Routes.new(site), sink)

    assert sink |> doc("posts/#{String.downcase(empty.public_id)}/index.html") |> title() ==
             "1. Januar 2025 · Site"
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

    description = "Quote &quot;this&quot; &lt;tag&gt; here."

    assert html =~ ~s(<title>Say "hi" &lt;now&gt; · Site</title>)
    assert html =~ ~s(<meta property="og:title" content="Say &quot;hi&quot; &lt;now&gt;">)
    assert html =~ ~s(<meta name="description" content="#{description}">)
    assert html =~ ~s(<meta property="og:description" content="#{description}">)
  end

  test "og:locale follows the site language", c do
    {:ok, site} = Sites.update_site(c.scope, c.scope.site, %{language_code: "de"})
    sink = RecordingSink.new(start_supervised!(RecordingSink, id: :german))
    :ok = Export.run(site, Routes.new(site, canonical_url: "https://example.com/"), sink)

    assert sink |> doc("index.html") |> meta("og:locale") == "de_DE"
  end
end
