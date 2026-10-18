defmodule Feather.StaticSite.Themes.SimpleSidebarTest do
  use Feather.DataCase

  alias Feather.{Books, Content, Sites}
  alias Feather.StaticSite.{Export, RecordingSink, Routes}
  alias Feather.StaticSite.Themes.SimpleSidebar

  @day ~U[2026-02-08 10:00:00.000000Z]
  @now ~U[2026-03-08 10:00:00.000000Z]

  defp build_site(attrs, opts \\ []) do
    scope = site_scope_fixture(Map.merge(%{theme: "simple_sidebar"}, attrs))

    publish_homepage(scope, Keyword.get(opts, :homepage, default_homepage()))
    create_pages(scope)
    create_book_review(scope)
    create_posts(scope)
    create_projects(scope)
    social_media_link_fixture(scope)

    scope = if opts[:portrait], do: put_portrait(scope), else: scope
    %{scope: scope, sink: export(scope)}
  end

  defp default_homepage do
    [
      %{"type" => "header", "level" => 2, "text" => "Hello"},
      paragraph("I build <b>websites</b> since 2001."),
      paragraph("A second paragraph.")
    ]
  end

  defp publish_homepage(scope, content) do
    {:ok, homepage} = Content.update_page(scope, Content.get_homepage(scope), %{content: content})
    {:ok, _} = Content.publish(scope, homepage)
  end

  defp create_pages(scope) do
    page_fixture(scope, %{title: "About me", slug: "/about", emoji: "👋", add_to_navigation: true})
    page_fixture(scope, %{title: "Imprint", slug: "/imprint", add_to_navigation: true})

    page_fixture(scope, %{
      title: "Books read",
      slug: "/books",
      emoji: "📙",
      page_type: "books",
      add_to_navigation: true
    })

    page_fixture(scope, %{
      title: "Projects",
      slug: "/work",
      emoji: "🛠️",
      page_type: "projects",
      add_to_navigation: true
    })
  end

  defp create_book_review(scope) do
    book =
      book_fixture(scope, %{
        title: "Virtua",
        author: "Karl Olsberg",
        rating: 4,
        emoji: "🧿",
        read_at: ~D[2026-02-01]
      })

    {:ok, %{post: review}} =
      Books.create_review(scope, book, %{
        slug: "/virtua",
        emoji: "🧿",
        content: [paragraph("I liked the overall plot.")],
        publish_at: @day
      })

    {:ok, _} = Content.publish(scope, review)
  end

  defp create_posts(scope) do
    post_fixture(scope, %{
      title: nil,
      slug: "/winter-ride",
      emoji: "🚲",
      content: [paragraph("Riding my bike in the cold."), paragraph("Empty trails.")],
      publish_at: DateTime.add(@day, 1, :day)
    })

    post_fixture(scope, %{
      title: "Loose Musings on AI Economics",
      slug: "/ai-economics",
      emoji: "🚗",
      tags: "ai, work",
      content: [paragraph("I have to admit: I'm impressed.")],
      publish_at: DateTime.add(@day, 2, :day)
    })
  end

  defp create_projects(scope) do
    project_fixture(scope, %{
      title: "Client portal",
      slug: "/client-portal",
      emoji: "🏢",
      project_type: "professional",
      status: "completed",
      company: "ACME",
      role: "Lead developer",
      started_at: ~D[2025-01-01],
      ended_at: ~D[2025-06-30],
      short_description: "A portal for clients."
    })

    project_fixture(scope, %{
      title: "feather.page",
      slug: "/feather-page",
      emoji: "🪶",
      project_type: "personal",
      status: "ongoing",
      started_at: ~D[2024-01-01],
      tags: "Elixir, Phoenix",
      short_description: "My own CMS.",
      links: [
        %{label: "Code", url: "https://www.example.com/code/"},
        %{label: "Website", url: "https://feather.example"}
      ]
    })
  end

  defp put_portrait(scope) do
    path = test_image_path(120, 120)
    {:ok, _} = Sites.put_portrait(scope, path, "me.png")
    File.rm(path)
    %{scope | site: Repo.reload!(scope.site)}
  end

  defp export(scope, now \\ @now) do
    sink = RecordingSink.new(start_supervised!(RecordingSink, id: make_ref()))
    :ok = Export.run(Repo.reload!(scope.site), Routes.new(scope.site), sink, now: now)
    sink
  end

  defp doc(sink, path), do: sink |> RecordingSink.get(path) |> LazyHTML.from_document()

  defp find(doc, selector), do: LazyHTML.query(doc, selector)

  defp text(doc, selector), do: doc |> find(selector) |> LazyHTML.text() |> String.trim()

  defp texts(doc, selector),
    do: doc |> find(selector) |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))

  defp attr(doc, selector, name), do: doc |> find(selector) |> LazyHTML.attribute(name)

  defp present?(doc, selector), do: doc |> find(selector) |> Enum.any?()

  @pages ~w(index.html ai-economics/index.html winter-ride/index.html about/index.html
            books/index.html work/index.html projects/feather-page/index.html 404.html)

  describe "the sidebar" do
    setup do
      build_site(
        %{
          title: "Robert Curth",
          domain: "rocu.de",
          emoji: "👨🏻‍💻",
          bio: "I build web apps. Mostly with Elixir."
        },
        portrait: true
      )
    end

    test "is on every page with title, domain, navigation and social links", %{sink: sink} do
      for path <- @pages do
        page = doc(sink, path)

        assert text(page, "header.sidebar .site-name") == "Robert Curth", path
        assert attr(page, "header.sidebar .site-name a", "href") == ["/"], path
        assert text(page, "header.sidebar .site-domain") == "rocu.de", path

        assert attr(page, "header.sidebar > nav.site-nav a", "href") ==
                 ["/about/", "/imprint/", "/books/", "/work/"],
               path

        assert texts(page, "header.sidebar > nav.site-nav a") ==
                 ["About me", "Imprint", "Books read", "Projects"],
               path

        assert texts(page, "header.sidebar .social-links a") == ["GitHub"], path
        refute present?(page, "script"), path
      end
    end

    test "shows portrait and bio on every page, inner pages are marked for the phone bar",
         %{sink: sink, scope: scope} do
      portrait = Repo.preload(scope.site, :portrait_image).portrait_image
      [home | others] = Enum.map(@pages, &{&1, doc(sink, &1)})

      {_path, home} = home
      refute present?(home, "header.sidebar--bar")

      assert attr(home, "header.sidebar img.portrait", "src") ==
               ["/images/#{portrait.public_id}/mobile_x1.webp"]

      assert text(home, "header.sidebar .bio") == "I build web apps. Mostly with Elixir."
      assert text(home, "footer.site-footer .bio") == "I build web apps. Mostly with Elixir."
      assert attr(home, "footer.site-footer img.footer-portrait", "sizes") == ["48px"]
      assert attr(home, "footer.site-footer img.footer-portrait", "alt") == [""]
      refute home |> text("header.sidebar") |> String.contains?("since 2001")

      for {path, page} <- others do
        assert present?(page, "header.sidebar.sidebar--bar"), path

        assert attr(page, "header.sidebar img.portrait", "src") ==
                 ["/images/#{portrait.public_id}/mobile_x1.webp"],
               path

        assert attr(page, "footer.site-footer .footer-bio img.footer-portrait", "src") ==
                 ["/images/#{portrait.public_id}/mobile_x1.webp"],
               path

        assert text(page, "header.sidebar .bio") == "I build web apps. Mostly with Elixir.", path

        assert text(page, "footer.site-footer .bio") == "I build web apps. Mostly with Elixir.",
               path
      end
    end

    test "the portrait is square and decorative, the site name a heading only at home", %{
      sink: sink
    } do
      home = doc(sink, "index.html")
      [portrait] = home |> find("img.portrait") |> Enum.to_list()

      assert LazyHTML.attribute(portrait, "width") == ["96"]
      assert LazyHTML.attribute(portrait, "height") == ["96"]
      assert LazyHTML.attribute(portrait, "alt") == [""]
      assert [_] = LazyHTML.attribute(portrait, "srcset")
      refute present?(home, ".portrait--emoji")

      assert text(home, "h1.site-name") == "Robert Curth"
      assert texts(doc(sink, "about/index.html"), "h1") == ["👋About me"]
      assert texts(doc(sink, "about/index.html"), "main h1 .title-emoji") == ["👋"]

      assert attr(doc(sink, "about/index.html"), "main h1 .title-emoji", "aria-hidden") == [
               "true"
             ]

      refute present?(doc(sink, "imprint/index.html"), "main h1 .title-emoji")
      refute present?(doc(sink, "about/index.html"), "h1.site-name")
    end

    test "marks the current page in the navigation with a square before its label", %{
      sink: sink
    } do
      about = doc(sink, "about/index.html")
      panel_nav = "header.sidebar > nav.site-nav"
      assert attr(about, ~s(#{panel_nav} a[aria-current="page"]), "href") == ["/about/"]

      assert attr(about, "#{panel_nav} .nav-mark", "aria-hidden") == ["true"]
      assert present?(about, ~s(#{panel_nav} a[aria-current="page"] > .nav-mark:first-child))

      home = doc(sink, "index.html")
      refute present?(home, "nav.site-nav a[aria-current]")
      refute present?(home, "nav.site-nav .nav-mark")

      project = doc(sink, "projects/feather-page/index.html")
      assert attr(project, ~s(#{panel_nav} a[aria-current="true"]), "href") == ["/work/"]
      assert present?(project, ~s(#{panel_nav} a[aria-current="true"] > .nav-mark))
      assert project |> find("#{panel_nav} .nav-mark") |> Enum.count() == 1
    end

    test "inner pages add a menu disclosure for phones next to the panel navigation", %{
      sink: sink
    } do
      [_home | others] = @pages

      for path <- others do
        page = doc(sink, path)

        assert text(page, "header.sidebar details.nav-menu > summary") == "Menu", path
        refute present?(page, "details.nav-menu[open]"), path
        assert page |> find("header.sidebar > nav.site-nav") |> Enum.count() == 1, path

        assert page |> find("header.sidebar details.nav-menu > nav.site-nav") |> Enum.count() == 1,
               path
      end

      about = doc(sink, "about/index.html")

      assert present?(
               about,
               ~s(details.nav-menu nav.site-nav a[aria-current="page"] > .nav-mark:first-child)
             )

      home = doc(sink, "index.html")
      refute present?(home, "details")
      refute present?(home, "summary")
      assert present?(home, "header.sidebar > nav.site-nav")
    end
  end

  describe "the sidebar of a plain site" do
    test "falls back to the site emoji and leaves out what is missing" do
      %{sink: sink} =
        build_site(%{title: "plain.example", domain: "plain.example", emoji: "🐭"},
          homepage: []
        )

      home = doc(sink, "index.html")

      assert text(home, "header.sidebar .portrait--emoji") == "🐭"
      assert attr(home, ".portrait--emoji", "aria-hidden") == ["true"]
      refute present?(home, "header.sidebar img")
      refute present?(home, ".site-domain")
      refute present?(home, ".bio")
      refute present?(home, "main > .content")
    end

    test "shows the footer bio without a picture when there is no portrait" do
      %{sink: sink} = build_site(%{title: "Robert", bio: "Hi."})

      home = doc(sink, "index.html")

      assert text(home, "footer.site-footer .bio") == "Hi."
      refute present?(home, ".footer-portrait")
    end

    test "has no bio paragraph without a bio, even when the homepage has text" do
      %{sink: sink} = build_site(%{title: "Robert"})

      home = doc(sink, "index.html")

      refute present?(home, ".bio")
      refute home |> text("header.sidebar") |> String.contains?("since 2001")
    end
  end

  describe "the home stream" do
    setup do
      build_site(%{title: "Robert Curth", domain: "rocu.de", emoji: "👨🏻‍💻"})
    end

    test "starts with the homepage content in the reading column", %{sink: sink} do
      home = doc(sink, "index.html")

      assert present?(home, "main > .content + #posts")
      assert texts(home, "main > .content h2") == ["Hello"]

      assert texts(home, "main > .content p") ==
               ["I build websites since 2001.", "A second paragraph."]

      assert text(home, "main > .content p b") == "websites"
    end

    test "then the posts, newest first, each with a meta line", %{sink: sink} do
      home = doc(sink, "index.html")

      refute present?(home, "main .bio")

      assert texts(home, "main article.entry .meta .meta-label .kind") ==
               ["Article", "Note", "Book"]

      assert texts(home, "main article.entry .meta > .meta-emoji:first-child") ==
               ["🚗", "🚲", "🧿"]

      assert attr(home, "main article.entry .meta > .meta-label + .rule", "aria-hidden") ==
               ["true", "true", "true"]

      assert attr(home, "main article.entry .meta time", "datetime") ==
               ["2026-02-10", "2026-02-09", "2026-02-08"]
    end

    test "an article shows its title, excerpt and a link to read on", %{sink: sink} do
      [article] = sink |> doc("index.html") |> find("article.entry--article") |> Enum.to_list()

      assert text(article, "h2 a") == "Loose Musings on AI Economics"
      assert attr(article, "h2 a", "href") == ["/ai-economics/"]
      assert text(article, ".excerpt") == "I have to admit: I'm impressed."
      assert attr(article, "a.more", "href") == ["/ai-economics/"]
      assert text(article, "a.more") =~ "Continue reading"
    end

    test "a note is shown in full without a title, its date links to it", %{sink: sink} do
      [note] = sink |> doc("index.html") |> find("article.entry--note") |> Enum.to_list()

      refute present?(note, "h2")
      refute present?(note, "a.more")
      assert texts(note, ".entry-body p") == ["Riding my bike in the cold.", "Empty trails."]
      assert attr(note, ".meta a", "href") == ["/winter-ride/"]
    end

    test "a book post shows the book, its author, rating and the review", %{sink: sink} do
      [book] = sink |> doc("index.html") |> find("article.entry--book") |> Enum.to_list()

      assert text(book, "h2 a") == "Virtua"
      assert attr(book, "h2 a", "href") == ["/virtua/"]
      assert text(book, ".byline .author") == "Karl Olsberg"
      assert attr(book, ".byline .stars", "aria-label") == ["4 of 5 stars"]
      assert texts(book, ".entry-body p") == ["I liked the overall plot."]
    end

    test "only the newest post carries the new label, at the end of its meta line", %{
      sink: sink
    } do
      home = doc(sink, "index.html")

      assert [label] = home |> find("article.entry .meta > .rule + .new") |> Enum.to_list()
      assert label |> LazyHTML.text() |> String.trim() == "New"
      assert LazyHTML.attribute(label, "aria-label") == ["Newest post"]
      assert LazyHTML.attribute(label, "role") == ["img"]
      assert home |> find("article.entry") |> Enum.at(0) |> find(".new") |> Enum.any?()
    end
  end

  test "a homepage holding only empty paragraphs leaves the reading column to the posts" do
    %{sink: sink} =
      build_site(%{title: "Robert"}, homepage: [paragraph(""), paragraph(" <br> ")])

    home = doc(sink, "index.html")

    refute present?(home, "main > .content")
    assert present?(home, "main > #posts")
  end

  test "a homepage holding only an image still shows its content" do
    scope = site_scope_fixture(%{theme: "simple_sidebar"})
    image = image_fixture(scope)
    publish_homepage(scope, [%{"type" => "image", "image_id" => image.public_id}])

    home = scope |> export() |> doc("index.html")

    assert present?(home, "main > .content img")
  end

  test "the new label and the homepage content are on the first page of the stream only, the bio on every page of it" do
    scope = site_scope_fixture(%{theme: "simple_sidebar", emoji: "🐭", bio: "Hi."})
    publish_homepage(scope, [paragraph("Welcome to my site.")])

    for day <- 1..26 do
      post_fixture(scope, %{publish_at: DateTime.add(@day, day, :day)})
    end

    sink = export(scope)

    home = doc(sink, "index.html")
    assert home |> find(".new") |> Enum.count() == 1
    assert text(home, "main > .content") == "Welcome to my site."
    assert text(home, "header.sidebar .bio") == "Hi."

    page_two = doc(sink, "page/2/index.html")
    assert page_two |> find("article.entry") |> Enum.count() == 1
    refute present?(page_two, ".new")
    refute present?(page_two, "main > .content")
    assert attr(page_two, ~s(nav.pagination [aria-current="page"]), "aria-current") == ["page"]
    assert text(page_two, "header.sidebar .bio") == "Hi."
    assert text(page_two, "header.sidebar .portrait--emoji") == "🐭"
    refute present?(page_two, ".sidebar--bar")
  end

  test "the new label is on the newest post only while it is at most 30 days old" do
    for {published_on, new?} <- [
          {~D[2026-10-11], true},
          {~D[2026-09-17], true},
          {~D[2026-09-16], false}
        ] do
      scope = site_scope_fixture(%{theme: "simple_sidebar"})
      post_fixture(scope, %{publish_at: DateTime.new!(published_on, ~T[22:00:00], "Etc/UTC")})

      home = scope |> export(~U[2026-10-17 08:00:00Z]) |> doc("index.html")

      assert present?(home, "article.entry .new") == new?, "#{published_on}"
    end
  end

  describe "a post" do
    setup do
      build_site(%{title: "Robert Curth", domain: "rocu.de", emoji: "👨🏻‍💻"})
    end

    test "shows the meta line, title, content, tags and the neighbours", %{sink: sink} do
      post = doc(sink, "winter-ride/index.html")

      assert text(post, "main .meta .kind") == "Note"
      assert attr(post, "main .meta time", "datetime") == ["2026-02-09"]
      assert texts(post, "main .meta time .punct") == [","]
      assert text(post, "main h1.visually-hidden") == "Riding my bike in the cold. Empty…"
      assert texts(post, "main .content p") == ["Riding my bike in the cold.", "Empty trails."]

      assert attr(post, "nav.post-nav .post-nav-newer a", "href") == ["/ai-economics/"]
      assert attr(post, "nav.post-nav .post-nav-older a", "href") == ["/virtua/"]
      assert text(post, "nav.post-nav .post-nav-older a") == "🧿Virtua"
      assert attr(post, "nav.post-nav .post-nav-all a", "href") == ["/#posts"]

      article = doc(sink, "ai-economics/index.html")
      assert text(article, "main h1") == "Loose Musings on AI Economics"
      refute present?(article, "main h1.visually-hidden")
      assert texts(article, "main .tags li") == ["ai", "work"]
      refute present?(article, "main .tags a")
      refute present?(article, ".new")
    end

    test "a book post names the book, its author and rating", %{sink: sink} do
      post = doc(sink, "virtua/index.html")

      assert text(post, "main h1") == "Virtua"
      assert text(post, "main .kind") == "Book"
      assert text(post, "main .byline .author") == "Karl Olsberg"
      assert attr(post, "main .byline .stars", "aria-label") == ["4 of 5 stars"]
      refute present?(post, "main .byline .book-title")
    end
  end

  test "a titled book post names the book in its byline" do
    %{scope: scope} = build_site(%{title: "Robert"})

    book =
      book_fixture(scope, %{
        title: "Qualityland",
        author: "Marc-Uwe Kling",
        rating: 3,
        read_at: ~D[2026-02-02]
      })

    {:ok, %{post: review}} =
      Books.create_review(scope, book, %{
        title: "Funny and sad",
        slug: "/qualityland",
        content: [paragraph("Ha.")],
        publish_at: DateTime.add(@day, 3, :day)
      })

    {:ok, _} = Content.publish(scope, review)
    sink = export(scope)

    post = doc(sink, "qualityland/index.html")
    assert text(post, "main h1") == "Funny and sad"
    assert text(post, "main .byline") == "Qualityland·Marc-Uwe Kling·★★★★★"
    assert text(post, "main .byline .book-title") == "Qualityland"

    home = doc(sink, "index.html")
    assert texts(home, "article.entry--book h2 a") == ["Funny and sad", "Virtua"]
    assert texts(home, "article.entry--book .byline .book-title") == ["Qualityland"]
  end

  test "the books page links a review only if the site shows it" do
    %{scope: scope} = build_site(%{title: "Robert"})
    book = book_fixture(scope, %{title: "Unwritten", read_at: ~D[2026-02-03]})

    {:ok, _draft} =
      Books.create_review(scope, book, %{
        slug: "/unwritten",
        content: [paragraph("Soon.")],
        publish_at: @day
      })

    books = doc(export(scope), "books/index.html")

    assert texts(books, "main .book a.book-title") == ["Virtua"]
    assert texts(books, "main .book span.book-title") == ["Unwritten"]
  end

  describe "pages and projects" do
    setup do
      build_site(%{title: "Robert Curth", domain: "rocu.de", emoji: "👨🏻‍💻"})
    end

    test "the books page lists read books by year", %{sink: sink} do
      books = doc(sink, "books/index.html")

      assert text(books, "main h1") == "📙Books read"
      assert texts(books, "main .books-year h2 .year") == ["2026"]
      assert texts(books, "main .books-year h2 .count") == ["1"]
      assert texts(books, "main .books-year h2 .visually-hidden") == [", 1 book"]
      assert text(books, "main .book .book-date") == "Feb 1"
      assert text(books, "main .book a.book-title") == "Virtua"
      assert attr(books, "main .book a.book-title", "href") == ["/virtua/"]
      assert text(books, "main .book .book-author") == "Karl Olsberg"
    end

    test "the 404 page links on", %{sink: sink} do
      not_found = doc(sink, "404.html")

      assert text(not_found, "main h1") == "Page not found"
      assert attr(not_found, "main .not-found-links a", "href") == ["/", "/#posts", "/work/"]
    end
  end

  describe "the projects page" do
    setup do
      %{scope: scope} = build_site(%{title: "Robert Curth", domain: "rocu.de"})

      wide = image_fixture(scope, %{width: 300, height: 100})
      tall = image_fixture(scope, %{width: 100, height: 300})
      header = image_fixture(scope, %{width: 160, height: 100})

      project_fixture(scope, %{
        title: "ZiWoAS",
        slug: "/ziwoas",
        emoji: "☀️",
        project_type: "open_source",
        started_at: ~D[2023-03-01],
        thumbnail_image_id: wide.id,
        header_image_id: header.id,
        short_description: "My own home automation.",
        content: [paragraph("Solar, plugs and lamps.")]
      })

      project_fixture(scope, %{
        title: "Zipfelkasse",
        slug: "/zipfelkasse",
        project_type: "freelance",
        started_at: ~D[2023-02-01],
        header_image_id: header.id,
        short_description: "Shared expenses for two."
      })

      project_fixture(scope, %{
        title: "TRMNL plugins",
        slug: "/trmnl",
        emoji: "🖼️",
        project_type: "personal",
        started_at: ~D[2023-01-01],
        thumbnail_image_id: tall.id,
        short_description: "Solar dashboards on e-ink."
      })

      project_fixture(scope, %{
        title: "Cooperative",
        slug: "/cooperative",
        project_type: "professional",
        status: "ongoing",
        period: "since 2019",
        started_at: ~D[2019-01-01],
        short_description: "A cooperative of specialists."
      })

      %{sink: export(scope), wide: wide, tall: tall, header: header}
    end

    test "lists own projects as rows with a picture, title, line and meta line", %{
      sink: sink,
      wide: wide,
      tall: tall,
      header: header
    } do
      projects = doc(sink, "work/index.html")

      assert texts(projects, "main ul.projects li.project h2 a") ==
               ["🪶feather.page", "☀️ZiWoAS", "Zipfelkasse", "🖼️TRMNL plugins"]

      assert texts(projects, "main li.project h2 a .title-emoji") == ["🪶", "☀️", "🖼️"]

      assert attr(projects, "main ul.projects li.project h2 a", "href") ==
               [
                 "/projects/feather-page/",
                 "/projects/ziwoas/",
                 "/projects/zipfelkasse/",
                 "/projects/trmnl/"
               ]

      assert texts(projects, "main li.project .project-description") ==
               [
                 "My own CMS.",
                 "My own home automation.",
                 "Shared expenses for two.",
                 "Solar dashboards on e-ink."
               ]

      assert texts(projects, "main li.project .meta .meta-label") ==
               ["Ongoing·elixir, phoenix·Code", "Ongoing", "Ongoing", "Ongoing"]

      assert projects |> find("main li.project .meta > .meta-label + .rule") |> Enum.count() ==
               4

      assert attr(projects, "main li.project .meta a", "href") ==
               ["https://www.example.com/code/"]

      assert attr(projects, "main li.project .project-shot img", "src") ==
               Enum.map([wide, header, tall], &"/images/#{&1.public_id}/mobile_x1.webp")

      assert attr(projects, "main li.project .project-shot img", "loading") ==
               ["lazy", "lazy", "lazy"]

      assert [_, _, _] = attr(projects, "main li.project .project-shot img", "srcset")
      assert projects |> find("main li.project .project-title + .meta") |> Enum.count() == 4
      assert projects |> find("main li.project--text") |> Enum.count() == 1
      refute present?(projects, "main li.project--text .project-shot")
      refute present?(projects, "main h2.projects-heading + ul li.project")
    end

    test "lists professional work after them as text rows", %{sink: sink} do
      projects = doc(sink, "work/index.html")

      assert texts(projects, "main h2.projects-heading") == ["Work"]
      assert texts(projects, "main ul.work li h3 a") == ["Cooperative", "🏢Client portal"]
      assert texts(projects, "main ul.work li h3 a .title-emoji") == ["🏢"]

      assert attr(projects, "main ul.work li h3 a", "href") ==
               ["/projects/cooperative/", "/projects/client-portal/"]

      assert texts(projects, "main ul.work li .meta .meta-label") ==
               ["since 2019", "Lead developer·ACME·Jan 2025 – Jun 2025"]

      assert texts(projects, "main ul.work li .project-description") ==
               ["A cooperative of specialists.", "A portal for clients."]

      assert projects |> find("main ul.work li .project-title + .meta") |> Enum.count() == 2
      refute present?(projects, "main ul.work img")
    end

    test "a project shows meta line, lead, picture, content and facts in that order", %{
      sink: sink,
      header: header
    } do
      project = doc(sink, "projects/ziwoas/index.html")

      assert project |> find("main article.project-page > *") |> LazyHTML.tag() ==
               ~w(h1 p div figure div dl p)

      assert text(project, "main h1") == "☀️ZiWoAS"
      assert texts(project, "main h1 .title-emoji") == ["☀️"]
      assert attr(project, "main h1 .title-emoji", "aria-hidden") == ["true"]
      assert text(project, "main .lead") == "My own home automation."

      assert attr(project, "main figure.project-image img", "src") ==
               ["/images/#{header.public_id}/desktop_x1.webp"]

      assert texts(project, "main .content p") == ["Solar, plugs and lamps."]
      assert attr(project, "main .project-back a", "href") == ["/work/"]
      assert text(project, "main .project-back a") == "All projects"
    end

    test "a project without a header image shows its thumbnail", %{sink: sink, tall: tall} do
      project = doc(sink, "projects/trmnl/index.html")

      assert attr(project, "main figure.project-image img", "src") ==
               ["/images/#{tall.public_id}/desktop_x1.webp"]

      refute present?(doc(sink, "projects/feather-page/index.html"), "main figure")
    end

    test "a project lists stack, status, work facts and links", %{sink: sink} do
      own = doc(sink, "projects/feather-page/index.html")

      assert text(own, "main .meta .meta-label") == "Ongoing·elixir, phoenix"
      assert present?(own, "main article.project-page > .meta > .meta-label + .rule")
      assert texts(own, "main dl.facts dt") == ["Stack", "Status", "Period", "Code", "Website"]

      assert texts(own, "main dl.facts dd") ==
               [
                 "elixir, phoenix",
                 "Ongoing",
                 "Jan 2024 – today",
                 "example.com/code",
                 "feather.example"
               ]

      assert attr(own, "main dl.facts dd a", "href") ==
               ["https://www.example.com/code/", "https://feather.example"]

      refute present?(own, "main .tags")

      work = doc(sink, "projects/client-portal/index.html")

      assert texts(work, "main dl.facts dt") == ["Status", "Role", "Company", "Period"]

      assert texts(work, "main dl.facts dd") ==
               ["Completed", "Lead developer", "ACME", "Jan 2025 – Jun 2025"]
    end
  end

  test "a projects page without professional projects has no work section" do
    scope = site_scope_fixture(%{theme: "simple_sidebar"})
    page_fixture(scope, %{title: "Projects", slug: "/projects-page", page_type: "projects"})
    project_fixture(scope, %{title: "Mine", project_type: "personal"})

    projects = doc(export(scope), "projects-page/index.html")

    assert texts(projects, "main li.project h2 a") == ["Mine"]
    refute present?(projects, "main .projects-heading")
    refute present?(projects, "main ul.work")
  end

  test "a German site labels the post kinds in German" do
    %{sink: sink} = build_site(%{title: "Robert", language_code: "de"})

    assert texts(doc(sink, "index.html"), "main .kind") == ["Artikel", "Notiz", "Buch"]
    assert text(doc(sink, "index.html"), "main .new") == "Neu"
    assert texts(doc(sink, "work/index.html"), "main h2.projects-heading") == ["Arbeit"]
    assert text(doc(sink, "work/index.html"), "details.nav-menu > summary") == "Menü"
    assert text(doc(sink, "books/index.html"), "main .book .book-date") == "01.02."
    assert texts(doc(sink, "books/index.html"), "main .book .book-date .punct") == [".", "."]

    assert text(doc(sink, "books/index.html"), "main .books-year h2 .visually-hidden") ==
             ", 1 Buch"

    project = doc(sink, "projects/feather-page/index.html")
    assert text(project, "main .project-back a") == "Alle Projekte"
    assert Enum.take(texts(project, "main dl.facts dt"), 2) == ["Technik", "Status"]
  end

  test "scripts and javascript: links from site data are neither run nor linked" do
    %{scope: scope} =
      build_site(%{title: "<script>alert(1)</script>", bio: "<script>alert(2)</script>Hi there."},
        homepage: [paragraph("<script>alert(5)</script>Welcome.")]
      )

    social_media_link_fixture(scope, %{name: "Evil", url: "javascript:alert(3)"})

    project_fixture(scope, %{
      title: "Evil project",
      slug: "/evil",
      project_type: "personal",
      links: [%{label: "Evil", url: "javascript:alert(4)"}]
    })

    sink = export(scope)

    for path <- ~w(index.html about/index.html work/index.html projects/evil/index.html) do
      html = RecordingSink.get(sink, path)
      page = LazyHTML.from_document(html)

      refute html =~ "<script", path
      refute html =~ ~r/javascript:/i, path
      refute present?(page, "script"), path
      assert text(page, "header.sidebar .site-name") == "<script>alert(1)</script>", path
    end

    home = doc(sink, "index.html")
    assert text(home, "header.sidebar .bio") == "<script>alert(2)</script>Hi there."
    assert text(home, "main > .content") == "Welcome."
    assert texts(home, "header.sidebar .social-links a") == ["GitHub"]
    refute "Evil" in texts(doc(sink, "projects/evil/index.html"), "main dl.facts dt")
  end

  test "content images declare the width of the reading column beside the panel" do
    scope = site_scope_fixture(%{theme: "simple_sidebar"})
    image = image_fixture(scope, width: 800, height: 600)
    page_fixture(scope, %{title: "Photos", slug: "/photos", content: [image_block(image)]})

    post_fixture(scope, %{
      title: "Shot",
      slug: "/shot",
      content: [image_block(image)],
      publish_at: @day
    })

    sink = export(scope)

    sizes =
      "(min-width: 58rem) 36rem, (min-width: 55.56rem) 62.1vw, " <>
        "(min-width: 52rem) calc(89.1vw - 15rem), calc(100vw - 2rem)"

    for path <- ~w(photos/index.html shot/index.html) do
      assert attr(doc(sink, path), "figure picture source", "sizes") == [sizes], path
    end

    assert RecordingSink.get(sink, "feed.xml") =~ "sizes=&quot;#{sizes}&quot;"
  end

  describe "fonts" do
    @mono_faces [
      {"jetbrains-mono-latin-400-normal.woff2", 400, "normal"},
      {"jetbrains-mono-latin-700-normal.woff2", 700, "normal"},
      {"jetbrains-mono-latin-400-italic.woff2", 400, "italic"}
    ]
    @mono_files ["OFL-JetBrains-Mono.txt" | Enum.map(@mono_faces, &elem(&1, 0))]

    setup do
      build_site(%{title: "Robert"})
    end

    test "the export writes the fonts and their licences into the site", %{sink: sink} do
      for name <- ~w(schibsted-grotesk-latin-wght.woff2 OFL.txt) ++ @mono_files do
        assert {:copy, source} = RecordingSink.get(sink, "fonts/" <> name)
        assert File.regular?(source)
        assert source == SimpleSidebar.font_path(name)
      end

      for name <- ~w(nunito-latin-700.woff2 nunito-latin-800.woff2) do
        refute RecordingSink.exists?(sink, "fonts/" <> name)
      end
    end

    test "the stylesheet declares the variable font against the site root", %{sink: sink} do
      css = RecordingSink.get(sink, "style.css")

      assert css =~ ~s[font-family: "Schibsted Grotesk"]
      assert css =~ "font-weight: 400 700"
      assert css =~ ~s[url("/fonts/schibsted-grotesk-latin-wght.woff2") format("woff2")]

      for {file, weight, style} <- @mono_faces do
        assert css =~
                 ~s[@font-face { font-family: "JetBrains Mono"; font-style: #{style}; ] <>
                   ~s[font-weight: #{weight}; font-display: swap; src: url("/fonts/#{file}") format("woff2"); }]
      end

      assert css =~ ~s[--mono: "JetBrains Mono", ui-monospace]
    end

    test "every page preloads the variable font", %{sink: sink} do
      html = RecordingSink.get(sink, "about/index.html")

      assert attr(LazyHTML.from_document(html), ~s(link[rel="preload"][as="font"]), "href") ==
               ["/fonts/schibsted-grotesk-latin-wght.woff2"]
    end
  end
end
