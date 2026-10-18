defmodule Feather.StaticSite.Themes.FeatherPageTest do
  use Feather.DataCase

  alias Feather.{Content, Sites}
  alias Feather.StaticSite.{Export, RecordingSink, Routes}
  alias Feather.StaticSite.Themes.FeatherPage
  alias Feather.StaticSite.Themes.FeatherPage.Hue

  @day ~U[2025-01-01 10:00:00.000000Z]

  defp build_site(attrs, opts) do
    scope = site_scope_fixture(attrs)

    page_fixture(scope, %{title: "About", slug: "/about", emoji: "👋", add_to_navigation: true})
    page_fixture(scope, %{title: "Imprint", slug: "/imprint", add_to_navigation: true})

    page_fixture(scope, %{
      title: "Work",
      slug: "/work",
      emoji: "💡",
      page_type: "projects",
      add_to_navigation: true
    })

    post_fixture(scope, %{title: "Older", slug: "/older", publish_at: @day})

    post_fixture(scope, %{
      title: "Newer",
      slug: "/newer",
      tags: "elixir, web",
      publish_at: DateTime.add(@day, 1, :day)
    })

    project_fixture(scope, %{title: "Thing", slug: "/thing", status: "completed"})

    scope = if opts[:dressed], do: dress(scope), else: scope

    sink = RecordingSink.new(start_supervised!(RecordingSink, id: make_ref()))
    :ok = Export.run(Repo.reload!(scope.site), Routes.new(scope.site), sink)
    %{scope: scope, sink: sink}
  end

  defp dress(scope) do
    header = image_fixture(scope, width: 1200, height: 675)
    homepage = Content.get_homepage(scope)
    {:ok, homepage} = Content.update_page(scope, homepage, %{header_image_id: header.id})
    {:ok, _} = Content.publish(scope, homepage)

    for slot <- Sites.mascot_slots() do
      path = test_image_path(90, 30)
      {:ok, _} = Sites.put_mascot(scope, slot, path, "#{slot}.png")
      File.rm(path)
    end

    %{scope | site: Repo.reload!(scope.site)}
  end

  defp doc(sink, path), do: sink |> RecordingSink.get(path) |> Floki.parse_document!()

  defp attr(doc, selector, name), do: Floki.attribute(doc, selector, name)

  defp text(doc, selector), do: doc |> Floki.find(selector) |> Floki.text() |> String.trim()

  @pages ~w(index.html newer/index.html about/index.html work/index.html projects/thing/index.html 404.html)

  describe "a site with homepage header image and mascots" do
    setup do
      build_site(%{title: "Mice", emoji: "🐭"}, dressed: true)
    end

    test "the accent hue comes from the site emoji", %{sink: sink} do
      for path <- @pages do
        assert attr(doc(sink, path), "html", "style") == ["--h: 350"], path
      end
    end

    test "the home masthead shows the header image, the title and the navigation", c do
      home = doc(c.sink, "index.html")
      header = Repo.preload(Content.get_homepage(c.scope), :header_image).header_image

      assert [img] = Floki.find(home, "header.masthead img.masthead-art")
      assert Floki.attribute(img, "src") == ["/images/#{header.public_id}/desktop_x1.webp"]
      assert Floki.attribute(img, "alt") == [""]
      assert Floki.attribute(img, "fetchpriority") == ["high"]

      assert {Floki.attribute(img, "width"), Floki.attribute(img, "height")} ==
               {["1200"], ["675"]}

      [srcset] = Floki.attribute(img, "srcset")
      refute srcset =~ ".jpg"
      assert [_ | _] = Floki.attribute(img, "sizes")

      assert Floki.find(home, ".masthead-emoji") == []
      assert text(home, "h1") == "Mice"
      assert Floki.find(home, "h1.site-title") != []
      assert Floki.find(home, ".breadcrumb") == []

      assert attr(home, ".masthead-links a.chip", "href") == ["/about/", "/imprint/", "/work/"]
      assert text(home, ~s(.masthead-links a[href="/about/"] .seal)) == "👋"
      assert Floki.find(home, ~s(.masthead-links a.chip--plain[href="/imprint/"] .seal)) == []
      assert Floki.find(home, "main .page-list a.page-link") == []
    end

    test "a post ends with the post end mascot beside newer and older", %{sink: sink} do
      post = doc(sink, "older/index.html")

      assert [mascot] = Floki.find(post, ".post-nav img.post-nav-mascot")
      assert Floki.attribute(mascot, "alt") == [""]
      assert Floki.attribute(mascot, "loading") == ["lazy"]
      assert Floki.attribute(mascot, "width") == ["90"]
      assert Floki.find(post, ".post-nav-seal") == []
    end

    test "the projects page shows its mascot beside the title, the page emoji as a badge", c do
      page = doc(c.sink, "work/index.html")

      assert text(page, ".title-row h1") == "Work"
      assert [mascot] = Floki.find(page, ".title-row .title-mascot img")
      assert Floki.attribute(mascot, "alt") == [""]
      assert text(page, ".title-row .title-mascot-badge") == "💡"
      assert Floki.find(page, "main > .emoji") == []

      assert Floki.find(doc(c.sink, "about/index.html"), ".title-row") == []
    end

    test "the 404 page shows the post end mascot and links on", %{sink: sink} do
      not_found = doc(sink, "404.html")

      assert [mascot] = Floki.find(not_found, ".not-found img.not-found-mascot")
      assert Floki.attribute(mascot, "alt") == [""]
      assert Floki.find(not_found, ".not-found-seal") == []
      assert attr(not_found, ".not-found a", "href") == ["/", "/#posts", "/work/"]
    end

    test "the footer mascot peeks over the footer on every page", %{sink: sink} do
      for path <- @pages do
        page = doc(sink, path)
        assert [mascot] = Floki.find(page, "footer img.footer-mascot"), path
        assert Floki.attribute(mascot, "alt") == [""]
        assert Floki.attribute(mascot, "loading") == ["lazy"]
        assert Floki.find(page, "footer .footer-emoji") == []
      end
    end
  end

  describe "a site with neither homepage header image nor mascots" do
    setup do
      build_site(%{title: "Coder", emoji: "👨🏻‍💻"}, [])
    end

    test "the masthead shows the site emoji in place of the image", %{sink: sink} do
      home = doc(sink, "index.html")

      assert Floki.find(home, "header.masthead img") == []
      assert text(home, "header.masthead .masthead-emoji") == "👨🏻‍💻"
      assert attr(home, "header.masthead .masthead-emoji", "aria-hidden") == ["true"]
      assert text(home, "h1") == "Coder"
      assert attr(home, "html", "style") == ["--h: 265"]
    end

    test "the site emoji stands in for every mascot", %{sink: sink} do
      post = doc(sink, "older/index.html")
      assert Floki.find(post, ".post-nav img") == []
      assert text(post, ".post-nav .post-nav-seal") == "👨🏻‍💻"

      not_found = doc(sink, "404.html")
      assert Floki.find(not_found, ".not-found img") == []
      assert text(not_found, ".not-found .not-found-seal") == "👨🏻‍💻"

      projects = doc(sink, "work/index.html")
      assert Floki.find(projects, ".title-row") == []
      assert text(projects, "main > .emoji") == "💡"

      for path <- @pages do
        page = doc(sink, path)
        assert Floki.find(page, "footer img") == [], path
        assert text(page, "footer .footer-emoji") == "👨🏻‍💻"
      end
    end

    test "tags and project status are labels, not links", %{sink: sink} do
      post = doc(sink, "newer/index.html")

      assert post |> Floki.find(".tags .tag") |> Enum.map(&Floki.text/1) == ["elixir", "web"]
      assert Floki.find(post, ".tags a") == []

      assert text(doc(sink, "work/index.html"), ".project-badges .badge.status-completed") ==
               "Completed"
    end
  end

  test "a site without emoji uses the neutral hue and shows no stand-ins" do
    %{sink: sink} = build_site(%{title: "Plain", emoji: nil}, [])

    for path <- @pages do
      page = doc(sink, path)
      assert attr(page, "html", "style") == ["--h: #{Hue.default()}"], path
      assert Floki.find(page, "footer .footer-emoji") == []
    end

    home = doc(sink, "index.html")
    assert Floki.find(home, ".masthead-emoji") == []
    assert text(home, "h1.site-title") == "Plain"
    assert Floki.find(doc(sink, "older/index.html"), ".post-nav-seal") == []
  end

  test "an untitled note is headed by the site title and titled by its first words" do
    scope = site_scope_fixture(%{title: "Zipfelmaus"})

    note =
      post_fixture(scope, %{title: nil, slug: nil, content: [paragraph("Short note.")]})

    sink = RecordingSink.new(start_supervised!(RecordingSink, id: make_ref()))
    :ok = Export.run(Repo.reload!(scope.site), Routes.new(scope.site), sink)
    post = doc(sink, "posts/#{String.downcase(note.public_id)}/index.html")

    assert text(post, "main h1") == "Zipfelmaus"
    assert text(post, ~s(.breadcrumb [aria-current="page"])) == "Zipfelmaus"
    assert text(post, "title") == "Short note. · Zipfelmaus"
  end

  describe "fonts" do
    @mono_faces [
      {"jetbrains-mono-latin-400-normal.woff2", 400, "normal"},
      {"jetbrains-mono-latin-700-normal.woff2", 700, "normal"},
      {"jetbrains-mono-latin-400-italic.woff2", 400, "italic"}
    ]
    @mono_files ["OFL-JetBrains-Mono.txt" | Enum.map(@mono_faces, &elem(&1, 0))]

    setup do
      build_site(%{title: "Mice", emoji: "🐭"}, [])
    end

    test "the export writes the fonts and their licences into the site", %{sink: sink} do
      for name <- ~w(nunito-latin-700.woff2 nunito-latin-800.woff2 OFL.txt) ++ @mono_files do
        assert {:copy, source} = RecordingSink.get(sink, "fonts/" <> name)
        assert File.regular?(source)
        assert source == FeatherPage.font_path(name)
      end

      refute RecordingSink.exists?(sink, "fonts/schibsted-grotesk-latin-wght.woff2")
    end

    test "every page declares the font faces against the site root", %{sink: sink} do
      html = RecordingSink.get(sink, "about/index.html")

      assert html =~ ~s[url("/fonts/nunito-latin-700.woff2") format("woff2")]
      assert html =~ ~s[url("/fonts/nunito-latin-800.woff2") format("woff2")]
      assert html =~ "font-display: swap"

      for {file, weight, style} <- @mono_faces do
        assert html =~
                 ~s[@font-face { font-family: "JetBrains Mono"; font-style: #{style}; ] <>
                   ~s[font-weight: #{weight}; font-display: swap; src: url("/fonts/#{file}") format("woff2"); }]
      end

      assert html =~ ~s[--mono: "JetBrains Mono", ui-monospace]
      refute html =~ "fonts.googleapis"
    end
  end

  test "font URLs follow the preview root" do
    scope = site_scope_fixture()
    routes = Routes.new(scope.site, site_root: "/preview/abc/")

    assert Routes.font_url(routes, "nunito-latin-800.woff2") ==
             "/preview/abc/fonts/nunito-latin-800.woff2"

    assert Routes.resolve(routes, "fonts/nunito-latin-800.woff2") ==
             {:font, "nunito-latin-800.woff2"}

    assert Routes.resolve(routes, "fonts/unknown.woff2") == nil
  end
end
