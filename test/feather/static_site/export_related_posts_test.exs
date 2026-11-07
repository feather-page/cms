defmodule Feather.StaticSite.ExportRelatedPostsTest do
  use Feather.DataCase

  alias Feather.Content
  alias Feather.StaticSite.{Export, Preview, RecordingSink, Routes}

  @themes ["feather", "simple_sidebar"]

  defp export(scope) do
    sink = RecordingSink.new(start_supervised!(RecordingSink, id: make_ref()))
    :ok = Export.run(Repo.reload!(scope.site), Routes.new(scope.site), sink)
    sink
  end

  defp page(sink, path), do: LazyHTML.from_document(RecordingSink.get(sink, path))

  defp related_links(doc) do
    doc
    |> LazyHTML.query("#related-posts li a")
    |> Enum.map(&{LazyHTML.attribute(&1, "href"), LazyHTML.text(&1)})
  end

  defp none?(doc, selector), do: doc |> LazyHTML.query(selector) |> Enum.empty?()

  defp unit(index, size \\ 4), do: for(i <- 0..(size - 1), do: if(i == index, do: 1.0, else: 0.0))

  defp post_at(scope, title, days_ago, attrs \\ %{}) do
    post_fixture(
      scope,
      Map.merge(
        %{
          title: title,
          slug: "/" <> String.downcase(title),
          publish_at: DateTime.add(~U[2026-11-01 12:00:00Z], -days_ago, :day)
        },
        attrs
      )
    )
  end

  defp titles(links), do: Enum.map(links, fn {_href, text} -> text end)

  describe "shared tags add a small bonus, tags on many posts count for nothing" do
    setup do
      scope = site_scope_fixture()
      scope |> post_at("A", 100, %{tags: "books, cycling"}) |> put_embedding(unit(0, 5))
      scope |> post_at("B", 2, %{tags: "books, cycling"}) |> put_embedding([0.8, 0.6, 0, 0, 0])
      scope |> post_at("C", 3) |> put_embedding([0.84, 0, :math.sqrt(1 - 0.84 * 0.84), 0, 0])
      scope |> post_at("D", 4) |> put_embedding([0.88, 0, 0, 0, :math.sqrt(1 - 0.88 * 0.88)])

      for n <- 1..46 do
        scope
        |> post_at("Filler#{n}", 4 + n, %{tags: if(n <= 10, do: "books")})
        |> put_embedding([0.1, 0, 0, :math.sqrt(0.99), 0])
      end

      %{scope: scope}
    end

    test "B scores 0.86 for A, between D at 0.88 and C at 0.84, since only the rare tag counts",
         %{scope: scope} do
      doc = page(export(scope), "a/index.html")

      assert related_links(doc) == [
               {["/d/"], "D\u00A02026"},
               {["/b/"], "B\u00A02026"},
               {["/c/"], "C\u00A02026"}
             ]
    end
  end

  describe "a post without a reading" do
    setup do
      scope = site_scope_fixture()
      post_at(scope, "Unread", 1)
      scope |> post_at("First", 2) |> put_embedding(unit(0))
      post_at(scope, "Spacer", 3)
      post_at(scope, "Gap", 4)
      scope |> post_at("Second", 5) |> put_embedding([0.9, 0.1, 0.0, 0.0])
      %{scope: scope}
    end

    test "shows no related posts and no other post lists it", %{scope: scope} do
      sink = export(scope)

      assert none?(page(sink, "unread/index.html"), "#related-posts")
      assert related_links(page(sink, "first/index.html")) == [{["/second/"], "Second\u00A02026"}]
      assert related_links(page(sink, "second/index.html")) == [{["/first/"], "First\u00A02026"}]
    end
  end

  describe "the post navigation of each theme" do
    test "starts with the related posts, without the newer and older post, which follow" do
      for theme <- @themes do
        domain = String.replace(theme, "_", "-") <> ".blog"
        scope = fediverse_scope_fixture(%{domain: domain, theme: theme})
        scope |> post_at("Bikes", 1) |> put_embedding(unit(0))
        scope |> post_at("Trains", 2, %{emoji: "🚂"}) |> put_embedding([0.95, 0.0, 0.312, 0.0])
        scope |> post_at("Wheels", 3, %{emoji: "🛞"}) |> put_embedding([0.9, 0.436, 0.0, 0.0])
        scope |> post_at("Boats", 4) |> put_embedding([0.3, 0.0, 0.0, 0.954])
        scope |> post_at("Cars", 5) |> put_embedding([0.2, 0.0, 0.0, 0.98])
        post_at(scope, "Alone", 6)

        sink = export(scope)
        doc = page(sink, "bikes/index.html")

        assert doc |> LazyHTML.query("nav.post-nav #related-posts-label") |> LazyHTML.text() ==
                 "Related posts",
               theme

        assert related_links(doc) == [
                 {["/wheels/"], "🛞Wheels\u00A02026"},
                 {["/boats/"], "Boats\u00A02026"},
                 {["/cars/"], "Cars\u00A02026"}
               ],
               theme

        assert doc |> LazyHTML.query(".post-nav-older a") |> LazyHTML.text() == "🚂Trains", theme
        refute none?(doc, "#replies ~ nav.post-nav .post-nav-related ~ .post-nav-older"), theme
        assert none?(doc, ".post-nav-older .post-nav-year"), theme
        assert none?(doc, "section.related-posts, .post-nav h2"), theme

        for link <- LazyHTML.query(doc, ".post-nav-link") do
          assert link |> LazyHTML.query(".post-nav-emoji") |> Enum.count() == 1, theme
        end

        alone = page(sink, "alone/index.html")
        assert none?(alone, "#related-posts, .post-nav-related"), theme
        refute none?(alone, ".post-nav-newer .post-nav-link"), theme
      end
    end

    test "still lists three when the newer and the older post are among the best matches" do
      scope = site_scope_fixture()
      scope |> post_at("Newer", 1) |> put_embedding([0.95, 0.312, 0.0, 0.0])
      scope |> post_at("Middle", 2) |> put_embedding(unit(0))
      scope |> post_at("Older", 3) |> put_embedding([0.94, 0.0, 0.341, 0.0])

      for {title, cosine} <- [{"X", 0.9}, {"Y", 0.8}, {"Z", 0.7}, {"W", 0.6}] do
        scope
        |> post_at(title, 10 + round(cosine * 10))
        |> put_embedding([cosine, 0.0, 0.0, :math.sqrt(1 - cosine * cosine)])
      end

      doc = page(export(scope), "middle/index.html")

      assert Enum.map(related_links(doc), fn {[href], _text} -> href end) == ["/x/", "/y/", "/z/"]
    end

    test "never lists a scheduled post" do
      scope = site_scope_fixture()
      scope |> post_at("Bikes", 1) |> put_embedding(unit(0))
      post_at(scope, "Spacer", 2)
      scope |> post_at("Wheels", 3) |> put_embedding([0.5, 0.866, 0.0, 0.0])

      scope
      |> post_at("Soon", -2, %{publish_at: DateTime.add(DateTime.utc_now(), 1, :day)})
      |> put_embedding(unit(0))

      exported = scope |> export() |> page("bikes/index.html") |> related_links()

      assert Enum.map(exported, fn {[href], _text} -> href end) == ["/wheels/"]

      assert preview_links(scope, "bikes") |> Enum.map(fn {[href], _} -> href end) |> length() ==
               1
    end

    test "names a short post by its meta title, and only without one by its first words" do
      scope = site_scope_fixture()
      scope |> post_at("Main", 1) |> put_embedding(unit(0))
      short_post(scope, "Solar", "Solar dashboard", 2)
      post_at(scope, "Spacer", 3)
      scope |> short_post("Rain", "Rain notes", 4) |> put_embedding([0.9, 0.436, 0.0, 0.0])
      post_at(scope, "Gap", 5)
      scope |> short_post("Fog", nil, 6) |> put_embedding([0.8, 0.0, 0.6, 0.0])

      sink = export(scope)
      main = page(sink, "main/index.html")

      assert main |> LazyHTML.query(".post-nav-older a") |> LazyHTML.text() == "Solar dashboard"

      assert titles(related_links(main)) == [
               "Rain notes\u00A02026",
               "Fog over the harbour\u00A02026"
             ]

      assert {["/main/"], "Main\u00A02026"} in related_links(page(sink, "rain/index.html"))
    end

    test "names the related posts in the site's language" do
      scope = site_scope_fixture(%{language_code: "de"})
      scope |> post_at("Bikes", 1) |> put_embedding(unit(0))
      post_at(scope, "Spacer", 2)
      scope |> post_at("Wheels", 3) |> put_embedding([0.9, 0.436, 0.0, 0.0])

      doc = page(export(scope), "bikes/index.html")

      assert doc |> LazyHTML.query("#related-posts-label") |> LazyHTML.text() ==
               "Ähnliche Beiträge"
    end
  end

  defp short_post(scope, slug, meta_title, days_ago) do
    post_at(scope, slug, days_ago, %{
      title: nil,
      meta_title: meta_title,
      content: [paragraph("#{slug} over the harbour")]
    })
  end

  describe "the preview" do
    defp preview_links(scope, path) do
      {:html, html} = Preview.render(Repo.reload!(scope.site), path)
      html |> IO.iodata_to_binary() |> LazyHTML.from_document() |> related_links()
    end

    defp paths(links),
      do:
        Enum.map(links, fn {[href], _text} ->
          href |> String.split("/", trim: true) |> List.last()
        end)

    test "compares the published versions, so it lists what the export lists" do
      scope = site_scope_fixture()
      bikes = scope |> post_at("Bikes", 1) |> put_embedding(unit(0))
      post_at(scope, "Spacer", 2)
      scope |> post_at("Wheels", 3) |> put_embedding([0.9, 0.436, 0.0, 0.0])
      post_at(scope, "Draft", 4, %{draft: true})

      {:ok, _changed} = Content.update_post(scope, bikes, %{title: "Bicycles"})

      assert [{[href], "Wheels\u00A02026"}] = preview_links(scope, "bikes")
      assert href =~ "/wheels/"
    end

    test "leaves out the newer and older post it shows, as the export does" do
      scope = site_scope_fixture()
      scope |> post_at("Bikes", 1) |> put_embedding(unit(0))
      scope |> post_at("Wheels", 2) |> put_embedding([0.9, 0.436, 0.0, 0.0])
      scope |> post_at("Trains", 3) |> put_embedding([0.5, 0.0, 0.866, 0.0])

      exported = scope |> export() |> page("bikes/index.html") |> related_links()

      assert paths(exported) == ["trains"]
      assert paths(preview_links(scope, "bikes")) == paths(exported)
    end

    test "takes the tags from the published versions, as the export does" do
      scope = site_scope_fixture()
      a = scope |> post_at("A", 10) |> put_embedding([1.0, 0.0, 0.0])
      post_at(scope, "Spacer", 9)
      scope |> post_at("B", 2, %{tags: "rare"}) |> put_embedding([0.80, 0.6, 0.0])
      scope |> post_at("C", 3) |> put_embedding([0.84, 0.0, :math.sqrt(1 - 0.84 * 0.84)])
      {:ok, _changed} = Content.update_post(scope, a, %{tags: "rare"})

      exported = scope |> export() |> page("a/index.html") |> related_links()

      assert paths(exported) == ["c", "b"]
      assert paths(preview_links(scope, "a")) == paths(exported)
    end

    test "counts the tags of published posts only, as the export does" do
      scope = site_scope_fixture()
      scope |> post_at("A", 10, %{tags: "rare"}) |> put_embedding([1.0, 0.0, 0.0])
      post_at(scope, "Spacer", 9)
      scope |> post_at("B", 2, %{tags: "rare"}) |> put_embedding([0.80, 0.6, 0.0])
      scope |> post_at("C", 3) |> put_embedding([0.84, 0.0, :math.sqrt(1 - 0.84 * 0.84)])
      for n <- 1..3, do: post_at(scope, "Draft#{n}", 3 + n, %{tags: "rare", draft: true})

      exported = scope |> export() |> page("a/index.html") |> related_links()

      assert paths(exported) == ["b", "c"]
      assert paths(preview_links(scope, "a")) == paths(exported)
    end
  end
end
