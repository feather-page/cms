defmodule Feather.StaticSite.ExportTest do
  use Feather.DataCase

  alias Feather.{Books, Content, Media, Sites}
  alias Feather.StaticSite.{Export, RecordingSink, Routes}

  @published_at ~U[2024-03-05 10:00:00.000000Z]

  setup do
    Feather.FakeChroma.install()

    scope =
      site_scope_fixture(%{title: "My <Site>", emoji: "🦉", copyright: "© {{CurrentYear}} Me"})

    {:ok, site} = Sites.update_site(scope, scope.site, %{})
    scope = %{scope | site: site}

    image = image_fixture(scope, width: 800, height: 600)

    header =
      image_fixture(scope, %{
        width: 1000,
        height: 563,
        unsplash_data: %{
          "photographer_name" => "Ann Lens",
          "photographer_url" => "https://unsplash.com/@ann"
        }
      })

    cover = image_fixture(scope, width: 200, height: 300)

    book =
      book_fixture(scope, %{
        title: "Dune",
        author: "Frank Herbert",
        emoji: "📙",
        rating: 4,
        read_at: ~D[2025-02-01],
        cover_image_id: cover.id
      })

    old_book = book_fixture(scope, %{title: "Old", author: "O. Author", read_at: ~D[2023-07-09]})
    book_fixture(scope, %{title: "Someday", author: "S", reading_status: "want_to_read"})

    {:ok, %{post: review}} =
      Books.create_review(scope, book, %{
        title: "",
        slug: "/dune-review",
        content: [paragraph("Loved it.")],
        publish_at: @published_at
      })

    {:ok, review} = Content.publish(scope, review)

    everything =
      post_fixture(scope, %{
        title: "Everything",
        slug: "/everything",
        emoji: "🧪",
        tags: "elixir, web",
        publish_at: DateTime.add(@published_at, 1, :day),
        header_image_id: header.id,
        thumbnail_image_id: image.id,
        content: [
          paragraph("Some <b>bold</b> <script>alert(1)</script>text."),
          %{"type" => "header", "level" => 3, "text" => "A section"},
          %{
            "type" => "list",
            "style" => "ol",
            "items" => [
              %{"content" => "One", "items" => [%{"content" => "Nested", "items" => []}]}
            ]
          },
          %{"type" => "quote", "text" => "Simplicity.", "caption" => "Dijkstra"},
          %{"type" => "code", "code" => "<b>x</b>", "language" => "html"},
          image_block(image, "An image"),
          %{"type" => "table", "content" => [["H1", "H2"], ["a", "b"]], "with_headings" => true},
          %{
            "type" => "embed",
            "service" => "youtube",
            "source" => "https://www.youtube.com/watch?v=abc",
            "embed" => "https://www.youtube.com/embed/abc",
            "width" => 580,
            "height" => 320,
            "caption" => "Video"
          },
          %{"type" => "book", "book_public_id" => book.public_id}
        ]
      })

    untitled =
      post_fixture(scope, %{title: nil, slug: nil, emoji: "💬", publish_at: @published_at})

    draft = post_fixture(scope, %{title: "Draft", slug: "/draft", draft: true})

    future =
      post_fixture(scope, %{
        title: "Future",
        slug: "/future",
        publish_at: DateTime.add(DateTime.utc_now(), 3600)
      })

    about =
      page_fixture(scope, %{title: "About", slug: "/about", emoji: "👋", add_to_navigation: true})

    page_fixture(scope, %{title: "Books", slug: "/books", page_type: "books"})
    page_fixture(scope, %{title: "Work", slug: "/work", page_type: "projects"})

    homepage = Content.get_homepage(scope)

    {:ok, homepage} =
      Content.update_page(scope, homepage, %{content: [paragraph("Welcome home.")]})

    {:ok, _} = Content.publish(scope, homepage)

    ongoing =
      project_fixture(scope, %{title: "Ongoing", slug: "/ongoing", started_at: ~D[2020-01-01]})

    project =
      project_fixture(scope, %{
        title: "Done",
        slug: "/done",
        status: "completed",
        company: "ACME",
        role: "Lead",
        tags: "rust",
        thumbnail_image_id: image.id,
        started_at: ~D[2024-01-01],
        ended_at: ~D[2024-06-30],
        short_description: "Line one\nline two\n\nSecond <b>para</b>",
        links: [
          %{label: "Code", url: "https://github.com/x"},
          %{label: "Evil", url: "javascript:alert(1)"}
        ]
      })

    social_media_link_fixture(scope)
    social_media_link_fixture(scope, %{name: "Bad", url: "javascript:alert(1)", icon: "rss"})

    routes = Routes.new(scope.site, canonical_url: "https://example.com/")
    sink = RecordingSink.new(start_supervised!(RecordingSink))
    :ok = Export.run(Feather.Repo.reload!(scope.site), routes, sink)

    %{
      scope: scope,
      sink: sink,
      image: image,
      header: header,
      cover: cover,
      book: book,
      old_book: old_book,
      review: review,
      everything: everything,
      untitled: untitled,
      draft: draft,
      future: future,
      about: about,
      project: project,
      ongoing: ongoing
    }
  end

  defp attr(node, name) do
    case Floki.attribute(node, name) do
      [value] -> value
      [] -> nil
    end
  end

  defp file(sink, path) do
    case RecordingSink.get(sink, path) do
      content when is_binary(content) -> content
      other -> flunk("#{path}: #{inspect(other)} in #{inspect(RecordingSink.paths(sink))}")
    end
  end

  defp compact(html), do: String.replace(html, ~r/\n */, "")

  test "writes every page, artifact and the image variants the images' roles need", c do
    paths = RecordingSink.paths(c.sink)

    for path <- [
          "index.html",
          "everything/index.html",
          "dune-review/index.html",
          "posts/#{String.downcase(c.untitled.public_id)}/index.html",
          "about/index.html",
          "books/index.html",
          "work/index.html",
          "projects/done/index.html",
          "projects/ongoing/index.html",
          "feed.xml",
          "robots.txt",
          "sitemap.xml",
          "style.css",
          "404.html",
          ".htaccess"
        ] do
      assert path in paths, "#{path} missing from #{inspect(paths)}"
    end

    refute "draft/index.html" in paths
    refute "future/index.html" in paths
    refute "page/2/index.html" in paths

    for {image, filenames} <- [
          {c.image, ~w(1200.jpg 128.webp 240.webp 480.webp 640.webp 960.webp)},
          {c.header, ~w(1200.jpg 1280.webp 640.webp 960.webp)},
          {c.cover, ~w(180.webp 360.webp)}
        ] do
      dir = "images/#{image.public_id}/"

      assert paths |> Enum.filter(&String.starts_with?(&1, dir)) |> Enum.sort() ==
               Enum.map(filenames, &(dir <> &1))

      for filename <- filenames do
        assert RecordingSink.get(c.sink, dir <> filename) ==
                 {:copy, Media.variant_path(image, filename)}
      end
    end
  end

  test "the post page renders every block type in the layout", c do
    html = file(c.sink, "everything/index.html")

    assert html =~ ~s(<html lang="en")
    assert html =~ "<title>Everything · My &lt;Site&gt;</title>"
    assert html =~ ~s(<link rel="stylesheet" href="/style.css?v=)
    # Only the emoji is interpolated (escaped); the rest is a fixed literal.
    assert html =~
             ~s(<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22%3E%3Ctext y=%22.9em%22 font-size=%2290%22%3E🧪%3C/text%3E%3C/svg%3E">)

    assert html =~ "🧪"
    assert html =~ "<h1>Everything</h1>"
    assert html =~ ~s(<a class="skip-link" href="#main">)
    assert html =~ ~s(<main id="main">)
    assert html =~ ~s(<nav class="breadcrumb" aria-label="Breadcrumb">)
    assert html =~ ~s(<span class="divider" aria-hidden="true">›</span>)
    assert html =~ ~s(<span aria-current="page">Everything</span>)

    assert html =~ "<p>Some <b>bold</b> text.</p>"
    refute html =~ "alert(1)"
    assert html =~ "<h3>A section</h3>"
    assert compact(html) =~ "<ol><li>One<ol><li>Nested</li></ol></li></ol>"
    assert compact(html) =~ "<blockquote><p>Simplicity.</p><cite>Dijkstra</cite></blockquote>"

    assert html =~
             ~s(<pre data-language="html"><code class="language-html"><span class="hl-fake">&lt;b&gt;x&lt;/b&gt;)

    assert compact(html) =~
             ~s(<figure><img loading="lazy" height="600" width="800" ) <>
               ~s(src="/images/#{c.image.public_id}/640.webp" ) <>
               ~s(srcset="/images/#{c.image.public_id}/640.webp 640w, /images/#{c.image.public_id}/960.webp 800w" )

    assert html =~ ~s(alt="An image")
    assert compact(html) =~ "<thead><tr><th>H1</th><th>H2</th></tr></thead>"
    assert html =~ "youtube-nocookie.com/embed/abc"
    assert html =~ ~s(<cite class="book-title">Dune</cite>)
    assert html |> Floki.parse_document!() |> Floki.attribute("img.header-image", "alt") == [""]

    assert html =~
             ~s(<a href="https://unsplash.com/@ann" target="_blank" rel="noopener">Ann Lens</a>)

    doc = Floki.parse_document!(html)

    assert Floki.attribute(doc, "h1 + p.post-meta time", "datetime") == ["2024-03-06"]
    assert doc |> Floki.find("p.post-meta") |> Floki.text() == "March 6, 2024"
    assert Floki.find(doc, ".post-date") == []

    assert doc |> Floki.find("ul.tags > li.tag") |> Enum.map(&Floki.text/1) == ["elixir", "web"]

    assert html =~
             ~s(<a href="https://github.com/johndoe" title="GitHub" aria-label="GitHub" class="socialLink">)

    assert html =~ ~s(<svg aria-hidden="true" focusable="false")
    refute html =~ ~s(title="Bad")
    assert html =~ "© #{Date.utc_today().year} Me"
  end

  test "the home page lists published posts, navigation and homepage content", c do
    html = file(c.sink, "index.html")

    assert html =~ "<title>My &lt;Site&gt;</title>"
    refute html =~ ~s(class="divider")
    assert html =~ ~s(<h1 class="site-title">My &lt;Site&gt;</h1>)

    assert html =~
             ~s(<a class="chip" href="/about/"><span class="seal" aria-hidden="true">👋</span>About</a>)

    assert html =~ "<p>Welcome home.</p>"
    assert html =~ ~s(<link rel="alternate" type="application/rss+xml" href="/feed.xml")
    assert html =~ ~s(<h3 class="post-title"><a href="/everything/">Everything</a></h3>)
    assert html =~ ~s(<div class="post-excerpt">)
    # The untitled review shows the book card with cover and rating.
    [cover] = html |> Floki.parse_document!() |> Floki.find("figure.book-card img.book-cover")
    assert attr(cover, "src") == "/images/#{c.cover.public_id}/180.webp"

    assert attr(cover, "srcset") ==
             "/images/#{c.cover.public_id}/180.webp 120w, /images/#{c.cover.public_id}/360.webp 200w"

    assert attr(cover, "sizes") == "80px"
    assert {attr(cover, "width"), attr(cover, "height")} == {"200", "300"}
    assert attr(cover, "loading") == "lazy"

    assert html =~
             ~s(<span class="book-rating" role="img" aria-label="4 of 5 stars"><span aria-hidden="true">★★★★☆</span></span>)

    assert compact(html) =~ ~s(<div class="post-content"><p>Loved it.</p></div>)
    assert html =~ ~s(<time datetime="2024-03-05">March 5, 2024</time>)
    refute html =~ "Draft"
    refute html =~ "Future"
    refute html =~ ~s(class="pagination")
  end

  test "the books page groups read books by year", c do
    html = file(c.sink, "books/index.html")

    assert html =~ "<h2>2025 (1)</h2>"
    assert html =~ "<h2>2023 (1)</h2>"
    refute html =~ "Someday"
    assert :binary.match(html, "2025 (1)") < :binary.match(html, "2023 (1)")

    assert html =~
             ~s(<span class="book-date"><time datetime="2025-02-01">Feb 1, 2025</time></span>)

    assert html =~ ~s(<a href="/dune-review/" class="book-title">Dune</a>)
    assert html =~ ~s(<span class="book-title">Old</span>)
    assert html =~ ~s(<span class="book-rating" role="img" aria-label="4 of 5 stars">)
  end

  test "the projects page lists ongoing projects first", c do
    html = file(c.sink, "work/index.html")

    assert :binary.match(html, "Ongoing") < :binary.match(html, ">Done<")
    assert html =~ ~s(<h2 class="project-title"><a href="/projects/done/">Done</a></h2>)
    assert html =~ ~s(<span class="badge status-completed">Completed</span>)
    assert html =~ "Open Source" or html =~ "Professional"
  end

  test "the project page", c do
    html = file(c.sink, "projects/done/index.html")

    assert html =~ ~s(<span class="project-company">ACME</span>)
    assert html =~ ~s(<span class="project-period">Jan 2024 – Jun 2024</span>)
    assert html =~ ~s(<div class="project-role">Lead</div>)
    assert compact(html) =~ "<p>Line one<br>line two</p><p>Second <b>para</b></p>"
    assert html =~ ~s(href="https://github.com/x")
    refute html =~ "javascript:"
  end

  test "the header image is sized for its slot, loads first and carries its credit", c do
    doc = c.sink |> file("everything/index.html") |> Floki.parse_document!()
    [header] = Floki.find(doc, "img.header-image")
    header_id = c.header.public_id

    assert attr(header, "src") == "/images/#{header_id}/640.webp"

    assert attr(header, "srcset") ==
             "/images/#{header_id}/640.webp 640w, /images/#{header_id}/960.webp 960w, " <>
               "/images/#{header_id}/1280.webp 1000w"

    assert attr(header, "sizes") == "(min-width: 38rem) 38rem, 100vw"
    assert {attr(header, "width"), attr(header, "height")} == {"1000", "563"}
    assert attr(header, "fetchpriority") == "high"
    assert attr(header, "loading") == nil

    assert Floki.attribute(doc, ".header-image-container .photo-credit a", "href") ==
             ["https://unsplash.com/@ann", "https://unsplash.com"]
  end

  test "home thumbnails are sized for their slot", c do
    [thumbnail] =
      c.sink |> file("index.html") |> Floki.parse_document!() |> Floki.find(".post-thumbnail img")

    id = c.image.public_id

    assert attr(thumbnail, "srcset") ==
             "/images/#{id}/240.webp 240w, /images/#{id}/480.webp 480w, /images/#{id}/960.webp 800w"

    assert attr(thumbnail, "sizes") == "(max-width: 600px) calc(100vw - 2rem), 240px"
    assert {attr(thumbnail, "width"), attr(thumbnail, "height")} == {"800", "600"}
    assert attr(thumbnail, "loading") == "lazy"
  end

  test "project thumbnails reserve their space and load lazily", c do
    [thumbnail] =
      c.sink
      |> file("work/index.html")
      |> Floki.parse_document!()
      |> Floki.find("img.project-thumbnail")

    assert {attr(thumbnail, "width"), attr(thumbnail, "height")} == {"28", "28"}
    assert attr(thumbnail, "loading") == "lazy"
  end

  test "book covers list their variants narrowest first, load lazily and reserve their space",
       c do
    [cover] =
      c.sink
      |> file("books/index.html")
      |> Floki.parse_document!()
      |> Floki.find("img.book-cover")

    assert attr(cover, "srcset") ==
             "/images/#{c.cover.public_id}/180.webp 120w, /images/#{c.cover.public_id}/360.webp 200w"

    assert attr(cover, "sizes") == "120px"
    assert attr(cover, "loading") == "lazy"
    assert attr(cover, "alt") == ""
    assert {attr(cover, "width"), attr(cover, "height")} == {"200", "300"}
  end

  test "a book card shows the cover or else the emoji", c do
    doc = c.sink |> file("books/index.html") |> Floki.parse_document!()

    assert Floki.find(doc, ".book-card .book-emoji") == []
    assert Floki.find(doc, ".book-card img.book-cover") != []
  end

  test "the RSS feed", c do
    xml = file(c.sink, "feed.xml")

    assert xml =~ ~s(<?xml version="1.0" encoding="UTF-8"?>)
    assert xml =~ ~s(<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">)
    assert xml =~ "<title>My &lt;Site&gt;</title>"
    assert xml =~ "<link>https://example.com/</link>"
    assert xml =~ "<description>My &lt;Site&gt; - RSS Feed</description>"
    assert xml =~ "<language>en</language>"

    assert xml =~
             ~s(<atom:link href="https://example.com/feed.xml" rel="self" type="application/rss+xml"/>)

    assert xml =~ "<title>Everything</title>"
    assert xml =~ "<pubDate>Wed, 06 Mar 2024 10:00:00 +0000</pubDate>"
    assert xml =~ ~s(<guid isPermaLink="true">https://example.com/everything/</guid>)
    assert xml =~ "&lt;p&gt;Some &lt;b&gt;bold&lt;/b&gt; text.&lt;/p&gt;"
    assert xml =~ "https://example.com/images/#{c.image.public_id}/640.webp"
    assert xml =~ "<title>Post</title>"
    refute xml =~ "Draft"
    assert {:ok, _} = Floki.parse_document(xml)
  end

  test "the sitemap", c do
    xml = file(c.sink, "sitemap.xml")

    assert xml =~ ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">)
    assert xml =~ "<loc>https://example.com/</loc>"
    assert xml =~ "<loc>https://example.com/everything/</loc>"
    assert xml =~ "<loc>https://example.com/about/</loc>"
    assert xml =~ "<loc>https://example.com/projects/done/</loc>"
    refute xml =~ "draft"
    refute xml =~ "future"

    lastmod =
      c.about |> Content.last_changed_at() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    assert xml =~ "<loc>https://example.com/about/</loc>\n    <lastmod>#{lastmod}</lastmod>"
    assert length(Regex.scan(~r/<loc>https:\/\/example.com\/<\/loc>/, xml)) == 1
  end

  test "the 404 page renders in the layout and links home", c do
    html = file(c.sink, "404.html")

    assert html =~ "<title>Page not found · My &lt;Site&gt;</title>"
    assert html =~ "<h1>Page not found</h1>"
    assert html =~ ~s(<span class="divider" aria-hidden="true">›</span>)

    assert html =~
             ~s(<a class="breadcrumb-home" href="/"><span class="seal" aria-hidden="true">🦉</span><span class="breadcrumb-site">My &lt;Site&gt;</span></a>)

    assert html =~ ~s(<a class="not-found-home" href="/">)
    assert html =~ ~s(<a class="not-found-posts" href="/#posts">All posts</a>)
    assert html =~ ~s(<a class="not-found-projects" href="/work/">Work</a>)
    refute file(c.sink, "sitemap.xml") =~ "404"
  end

  test "writes the IndexNow key file at the site root", c do
    key = c.scope.site.indexnow_key
    assert file(c.sink, "#{key}.txt") == key
  end

  test "robots.txt lets every crawler in, allows every use of the content and points at the canonical sitemap",
       c do
    assert file(c.sink, "robots.txt") == """
           User-agent: *
           Content-Signal: search=yes, ai-input=yes, ai-train=yes
           Allow: /

           Sitemap: https://example.com/sitemap.xml
           """
  end
end

defmodule Feather.StaticSite.ExportPaginationTest do
  use Feather.DataCase

  alias Feather.StaticSite.{Export, RecordingSink, Routes}

  test "paginates the post list by 25 with links between the pages" do
    scope = site_scope_fixture()

    for i <- 1..27 do
      post_fixture(scope, %{
        title: "Post #{i}",
        publish_at: DateTime.add(~U[2024-01-01 00:00:00.000000Z], i, :day)
      })
    end

    sink = RecordingSink.new(start_supervised!(RecordingSink))
    :ok = Export.run(scope.site, Routes.new(scope.site), sink)

    first = RecordingSink.get(sink, "index.html")
    second = RecordingSink.get(sink, "page/2/index.html")

    assert first =~ ">Post 27<"
    refute first =~ ">Post 2<"
    assert first =~ ~s(<a href="/page/2/" class="pagination-link">2</a>)
    assert first =~ ~s(<span class="pagination-current" aria-current="page">1</span>)
    assert second =~ ">Post 2<"
    assert second =~ ">Post 1<"

    assert second =~
             ~s(<a href="/" class="pagination-link" aria-label="Previous page">←</a>)

    refute RecordingSink.exists?(sink, "page/3/index.html")
  end

  test "numbers the titles of the post list pages after the first, in the site's language" do
    for {language_code, page_two} <- [{"en", "Page 2 · Blog"}, {"de", "Seite 2 · Blog"}] do
      scope = site_scope_fixture(%{title: "Blog", language_code: language_code})

      for i <- 1..26 do
        post_fixture(scope, %{publish_at: DateTime.add(~U[2024-01-01 00:00:00.000000Z], i, :day)})
      end

      sink = RecordingSink.new(start_supervised!(RecordingSink, id: language_code))
      :ok = Export.run(scope.site, Routes.new(scope.site), sink)

      assert title(sink, "index.html") == "Blog"
      assert title(sink, "page/2/index.html") == page_two
    end
  end

  defp title(sink, path),
    do:
      sink
      |> RecordingSink.get(path)
      |> Floki.parse_document!()
      |> Floki.find("title")
      |> Floki.text()
end
