defmodule Feather.StaticSite.LocalisationTest do
  use Feather.DataCase

  alias Feather.Books
  alias Feather.StaticSite.{Export, RecordingSink, Routes, Templates}

  defp export_site(language_code) do
    scope = site_scope_fixture(%{title: "Site", language_code: language_code})

    post_fixture(scope, %{
      title: "A post",
      slug: "/a-post",
      publish_at: ~U[2025-05-06 10:00:00.000000Z]
    })

    book =
      book_fixture(scope, %{title: "Dune", author: "F. H.", rating: 4, read_at: ~D[2026-08-12]})

    {:ok, %{post: review}} =
      Books.create_review(scope, book, %{
        title: "Dune review",
        slug: "/dune",
        content: [paragraph("Good.")],
        publish_at: ~U[2025-01-02 10:00:00.000000Z]
      })

    {:ok, _} = Feather.Content.publish(scope, review)

    page_fixture(scope, %{title: "Books", slug: "/books", page_type: "books"})
    page_fixture(scope, %{title: "Work", slug: "/work", page_type: "projects"})

    project_fixture(scope, %{
      title: "Thing",
      slug: "/thing",
      status: "ongoing",
      project_type: "personal",
      started_at: ~D[2024-01-01],
      links: [%{label: "Code", url: "https://example.com/code"}]
    })

    sink = RecordingSink.new(start_supervised!(RecordingSink))
    :ok = Export.run(scope.site, Routes.new(scope.site), sink)
    sink
  end

  defp text(html, selector),
    do: html |> Floki.parse_document!() |> Floki.find(selector) |> Floki.text() |> String.trim()

  describe "a German site" do
    setup do
      %{sink: export_site("de")}
    end

    test "labels the theme chrome in German", %{sink: sink} do
      home = RecordingSink.get(sink, "index.html")

      assert home =~ ~s(<html lang="de")
      assert text(home, ".skip-link") == "Zum Inhalt springen"
      assert text(home, "h2#posts") == "Beiträge"

      project = RecordingSink.get(sink, "projects/thing/index.html")
      assert project =~ "Laufend"
      assert project =~ "Jan. 2024 – heute"
      assert RecordingSink.get(sink, "work/index.html") =~ "Privat"

      books = RecordingSink.get(sink, "books/index.html")
      assert books =~ ~s(aria-label="4 von 5 Sternen")

      not_found = RecordingSink.get(sink, "404.html")
      assert not_found =~ "<title>Seite nicht gefunden · Site</title>"
      assert text(not_found, ".not-found-home") == "Zur Startseite"
    end

    test "writes dates in German inside time elements", %{sink: sink} do
      post = RecordingSink.get(sink, "a-post/index.html")
      assert post =~ ~s(<time datetime="2025-05-06">6. Mai 2025</time>)

      books = RecordingSink.get(sink, "books/index.html")
      assert books =~ ~s(<time datetime="2026-08-12">12.08.2026</time>)
    end
  end

  test "any other language falls back to English" do
    sink = export_site("fr")
    home = RecordingSink.get(sink, "index.html")

    assert home =~ ~s(<html lang="fr")
    assert text(home, ".skip-link") == "Skip to content"
    assert text(home, "h2#posts") == "Posts"
    assert home =~ ~s(<time datetime="2025-05-06">May 6, 2025</time>)

    books = RecordingSink.get(sink, "books/index.html")
    assert books =~ ~s(<time datetime="2026-08-12">Aug 12, 2026</time>)
    assert books =~ ~s(aria-label="4 of 5 stars")

    project = RecordingSink.get(sink, "projects/thing/index.html")
    assert project =~ "Ongoing"
    assert project =~ "Jan 2024 – today"
  end

  test "date formats per language" do
    date = ~D[2025-05-06]

    Gettext.with_locale(Feather.StaticSite.Gettext, "en", fn ->
      assert Templates.format_date(date) == "May 6, 2025"
      assert Templates.format_short_date(date) == "May 6, 2025"
      assert Templates.format_short_date(~D[2026-08-12]) == "Aug 12, 2026"
      assert Templates.rating_label(9) == "5 of 5 stars"
    end)

    Gettext.with_locale(Feather.StaticSite.Gettext, "de", fn ->
      assert Templates.format_date(date) == "6. Mai 2025"
      assert Templates.format_date(~U[2024-03-06 23:00:00Z]) == "6. März 2024"
      assert Templates.format_short_date(date) == "06.05.2025"
      assert Templates.rating_label(4) == "4 von 5 Sternen"
    end)
  end
end
