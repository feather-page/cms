defmodule Feather.StaticSite.ExportTest do
  use Feather.DataCase

  alias Feather.{Books, Content, Media, Sites}
  alias Feather.StaticSite.{Export, RecordingSink, Routes}

  @published_at ~U[2024-03-05 10:00:00.000000Z]

  setup do
    scope = site_scope_fixture(%{title: "My <Site>", emoji: "🦉", copyright: "© {{CurrentYear}} Me"})
    {:ok, site} = Sites.update_site(scope, scope.site, %{})
    scope = %{scope | site: site}

    image = image_fixture(scope, width: 80, height: 60)

    header =
      image_fixture(scope, %{
        unsplash_data: %{
          "photographer_name" => "Ann Lens",
          "photographer_url" => "https://unsplash.com/@ann"
        }
      })

    cover = image_fixture(scope)

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

    everything =
      post_fixture(scope, %{
        title: "Everything",
        slug: "/everything",
        emoji: "🧪",
        tags: "elixir, web",
        publish_at: DateTime.add(@published_at, 1, :day),
        header_image_id: header.id,
        content: [
          paragraph("Some <b>bold</b> <script>alert(1)</script>text."),
          %{"type" => "header", "level" => 3, "text" => "A section"},
          %{
            "type" => "list",
            "style" => "ol",
            "items" => [%{"content" => "One", "items" => [%{"content" => "Nested", "items" => []}]}]
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

    untitled = post_fixture(scope, %{title: nil, slug: nil, emoji: "💬", publish_at: @published_at})
    draft = post_fixture(scope, %{title: "Draft", slug: "/draft", draft: true})

    future =
      post_fixture(scope, %{
        title: "Future",
        slug: "/future",
        publish_at: DateTime.add(DateTime.utc_now(), 3600)
      })

    about = page_fixture(scope, %{title: "About", slug: "/about", emoji: "👋", add_to_navigation: true})
    page_fixture(scope, %{title: "Books", slug: "/books", page_type: "books"})
    page_fixture(scope, %{title: "Work", slug: "/work", page_type: "projects"})

    homepage = Content.get_homepage(scope)
    {:ok, _} = Content.update_page(scope, homepage, %{content: [paragraph("Welcome home.")]})

    ongoing = project_fixture(scope, %{title: "Ongoing", slug: "/ongoing", started_at: ~D[2020-01-01]})

    project =
      project_fixture(scope, %{
        title: "Done",
        slug: "/done",
        status: "completed",
        company: "ACME",
        role: "Lead",
        tags: "rust",
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

  defp file(sink, path) do
    case RecordingSink.get(sink, path) do
      content when is_binary(content) -> content
      other -> flunk("#{path}: #{inspect(other)} in #{inspect(RecordingSink.paths(sink))}")
    end
  end

  test "writes every page, artifact and image variant", c do
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
          "sitemap.xml"
        ] do
      assert path in paths, "#{path} missing from #{inspect(paths)}"
    end

    refute "draft/index.html" in paths
    refute "future/index.html" in paths
    refute "page/2/index.html" in paths

    for image <- [c.image, c.header, c.cover], filename <- Media.Variants.filenames() do
      path = "images/#{image.public_id}/#{filename}"
      assert RecordingSink.get(c.sink, path) == {:copy, Media.variant_path(image, filename)}
    end
  end

  test "the post page renders every block type in the layout", c do
    html = file(c.sink, "everything/index.html")

    assert html =~ ~s(<html lang="en">)
    assert html =~ "<title>Everything</title>"
    assert html =~ "<style>"
    assert html =~ "data:image/svg+xml"
    assert html =~ "🧪"
    assert html =~ "<h1>Everything</h1>"
    assert html =~ ~s(<span class="divider">/</span>)
    assert html =~ "<p>Some <b>bold</b> text.</p>"
    refute html =~ "alert(1)"
    assert html =~ "<h3>A section</h3>"
    assert html =~ "<ol><li>One<ol><li>Nested</li></ol></li></ol>"
    assert html =~ "<blockquote><p>Simplicity.</p><cite>Dijkstra</cite></blockquote>"
    assert html =~ "<pre><code>&lt;b&gt;x&lt;/b&gt;</code></pre>"
    assert html =~ ~s(src="/images/#{c.image.public_id}/desktop_x1.jpg" alt="An image")
    assert html =~ "<thead><tr><td>H1</td><td>H2</td></tr></thead>"
    assert html =~ "youtube-nocookie.com/embed/abc"
    assert html =~ ~s(<div class="book-title">Dune</div>)
    assert html =~ ~s(class="header-image")
    assert html =~ ~s(srcset="/images/#{c.header.public_id}/mobile_x1.webp 430w)
    assert html =~ ~s(<a href="https://unsplash.com/@ann" target="_blank" rel="noopener">Ann Lens</a>)
    assert html =~ ~s(<div class="post-date">March 06, 2024</div>)
    assert html =~ ~s(<span class="badge badge-outline">elixir</span>)
    assert html =~ ~s(<a href="https://github.com/johndoe" title="GitHub" class="socialLink">)
    assert html =~ "<svg"
    refute html =~ ~s(title="Bad")
    assert html =~ "© #{Date.utc_today().year} Me"
  end

  test "the home page lists published posts, navigation and homepage content", c do
    html = file(c.sink, "index.html")

    assert html =~ "<title>My &lt;Site&gt;</title>"
    refute html =~ ~s(class="divider")
    assert html =~ ~s(<a class="page-link" href="/about/">About</a>)
    assert html =~ "<p>Welcome home.</p>"
    assert html =~ ~s(<link rel="alternate" type="application/rss+xml" href="/feed.xml")
    assert html =~ ~s(<a class="post-title" href="/everything/">Everything</a>)
    assert html =~ ~s(<div class="post-excerpt">)
    # The untitled review shows the book card with cover and rating.
    assert html =~ ~s(<img src="/images/#{c.cover.public_id}/mobile_x1.webp" alt="Dune")
    assert html =~ "★★★★☆"
    assert html =~ ~s(<div class="post-content"><p>Loved it.</p></div>)
    assert html =~ "March 05, 2024"
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
    assert html =~ ~s(<span class="book-date">01/02/2025</span>)
    # The review has no title, so the book is not linked.
    assert html =~ ~s(<span class="book-title">Dune</span>)
  end

  test "the projects page lists ongoing projects first", c do
    html = file(c.sink, "work/index.html")

    assert :binary.match(html, "Ongoing") < :binary.match(html, ">Done<")
    assert html =~ ~s(<a href="/projects/done/" class="project-title">Done</a>)
    assert html =~ ~s(<span class="badge badge-success">)
    assert html =~ "Open Source" or html =~ "Professional"
  end

  test "the project page", c do
    html = file(c.sink, "projects/done/index.html")

    assert html =~ ~s(<span class="project-company">ACME</span>)
    assert html =~ ~s(<span class="project-period">01.2024 - 06.2024</span>)
    assert html =~ ~s(<div class="project-role">Lead</div>)
    assert html =~ "<p>Line one\n<br />line two</p>\n\n<p>Second <b>para</b></p>"
    assert html =~ ~s(href="https://github.com/x")
    refute html =~ "javascript:"
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
    assert xml =~ "https://example.com/images/#{c.image.public_id}/desktop_x1.jpg"
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

    lastmod = c.about.updated_at |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    assert xml =~ "<loc>https://example.com/about/</loc>\n    <lastmod>#{lastmod}</lastmod>"
    assert length(Regex.scan(~r/<loc>https:\/\/example.com\/<\/loc>/, xml)) == 1
  end

  test "robots.txt points at the canonical sitemap", c do
    assert file(c.sink, "robots.txt") ==
             "User-agent: *\nAllow: /\n\nSitemap: https://example.com/sitemap.xml\n"
  end
end

defmodule Feather.StaticSite.ExportPaginationTest do
  use Feather.DataCase

  alias Feather.StaticSite.{Export, RecordingSink, Routes, Templates}

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
    assert first =~ ~s(<span class="pagination-current">1</span>)
    assert second =~ ">Post 2<"
    assert second =~ ">Post 1<"
    assert second =~ ~s(<a href="/" class="pagination-link">&larr;</a>)
    refute RecordingSink.exists?(sink, "page/3/index.html")
  end

  test "pagination page numbers with gaps" do
    assert Templates.pagination_page_numbers(1, 5) == [1, 2, 3, 4, 5]
    assert Templates.pagination_page_numbers(1, 10) == [1, 2, 3, 4, :gap, 10]
    assert Templates.pagination_page_numbers(5, 10) == [1, :gap, 4, 5, 6, :gap, 10]
    assert Templates.pagination_page_numbers(9, 10) == [1, :gap, 7, 8, 9, 10]
  end
end
