defmodule Feather.StaticSite.StructuredDataTest do
  use Feather.DataCase

  alias Feather.{Books, Content, Repo, Sites}
  alias Feather.StaticSite.{Export, RecordingSink, Routes}

  @day ~U[2026-10-01 08:00:00.000000Z]

  setup do
    scope = site_scope_fixture(%{title: "Ada Lovelace", bio: "Writes about <engines>."})
    %{scope: scope}
  end

  defp export(scope, id \\ :export) do
    sink = RecordingSink.new(start_supervised!(RecordingSink, id: id))
    site = Repo.reload!(scope.site)
    :ok = Export.run(site, Routes.new(site, canonical_url: "https://example.com/"), sink)
    sink
  end

  defp json_ld(sink, path) do
    html = RecordingSink.get(sink, path)

    case html |> Floki.parse_document!() |> Floki.find(~s(script[type="application/ld+json"])) do
      [script] -> script |> Floki.children() |> Enum.join() |> Jason.decode!()
      [] -> nil
    end
  end

  defp typed(%{"@graph" => graph}, type), do: Enum.find(graph, &(&1["@type"] == type))

  test "a post is a blog posting by the site's person", %{scope: scope} do
    header = image_fixture(scope)

    post =
      post_fixture(scope, %{
        title: "Engines",
        slug: "/engines",
        header_image_id: header.id,
        publish_at: @day,
        content: [paragraph("The analytical engine weaves algebraic patterns.")]
      })

    sink = export(scope)
    data = json_ld(sink, "engines/index.html")
    posting = typed(data, "BlogPosting")
    published = Repo.preload(post, :published_version).published_version.published_at

    assert data["@context"] == "https://schema.org"
    assert posting["headline"] == "Engines"
    assert posting["url"] == "https://example.com/engines/"
    assert posting["mainEntityOfPage"] == "https://example.com/engines/"
    assert posting["datePublished"] == "2026-10-01T08:00:00Z"
    assert posting["dateModified"] == iso8601(Enum.max([published, @day], DateTime))
    assert posting["description"] == "The analytical engine weaves algebraic patterns."
    assert posting["image"] == "https://example.com/images/#{header.public_id}/1200.jpg"
    assert posting["inLanguage"] == "en"

    assert posting["author"] == %{
             "@type" => "Person",
             "@id" => "https://example.com/#person",
             "name" => "Ada Lovelace",
             "url" => "https://example.com/"
           }

    assert typed(data, "Review") == nil
  end

  test "a post without an image shows its share card", %{scope: scope} do
    post_fixture(scope, %{title: "Plain", slug: "/plain"})

    posting = scope |> export() |> json_ld("plain/index.html") |> typed("BlogPosting")

    assert posting["image"] =~ ~r"\Ahttps://example\.com/images/[0-9a-f]{64}\.png\z"
  end

  test "a review rates its book", %{scope: scope} do
    book =
      book_fixture(scope, %{
        title: "Dune",
        author: "Frank Herbert",
        isbn: "9780441013593",
        rating: 4
      })

    {:ok, %{post: review}} =
      Books.create_review(scope, book, %{slug: "/dune", content: [paragraph("Loved it.")]})

    {:ok, _} = Content.publish(scope, review)

    data = scope |> export() |> json_ld("dune/index.html")
    review = typed(data, "Review")

    assert typed(data, "BlogPosting")["headline"] == "Dune"
    assert review["url"] == "https://example.com/dune/"
    assert review["author"] == %{"@id" => "https://example.com/#person"}

    assert review["itemReviewed"] == %{
             "@type" => "Book",
             "name" => "Dune",
             "author" => %{"@type" => "Person", "name" => "Frank Herbert"},
             "isbn" => "9780441013593"
           }

    assert review["reviewRating"] == %{
             "@type" => "Rating",
             "ratingValue" => 4,
             "bestRating" => 5,
             "worstRating" => 1
           }
  end

  test "an unrated review has no rating", %{scope: scope} do
    book = book_fixture(scope, %{title: "Emma", rating: nil})
    {:ok, %{post: review}} = Books.create_review(scope, book, %{slug: "/emma"})
    {:ok, _} = Content.publish(scope, review)

    review = scope |> export() |> json_ld("emma/index.html") |> typed("Review")

    refute Map.has_key?(review, "reviewRating")
    refute Map.has_key?(review["itemReviewed"], "isbn")
  end

  test "the home page is the site and its person", %{scope: scope} do
    {:ok, site} = Sites.update_site(scope, scope.site, %{theme: "simple_sidebar"})
    scope = %{scope | site: site}
    path = test_image_path(600, 600)
    {:ok, site} = Sites.put_portrait(scope, path, "me.png")
    File.rm(path)
    social_media_link_fixture(scope, %{url: "https://github.com/ada"})
    social_media_link_fixture(scope, %{name: "Bad", url: "javascript:alert(1)"})
    social_media_link_fixture(scope, %{name: "Mail", url: "mailto:ada@example.com"})
    social_media_link_fixture(scope, %{name: "Phone", url: "tel:+441234"})
    social_media_link_fixture(scope, %{name: "Local", url: "/about"})
    portrait = Repo.preload(site, :portrait_image).portrait_image

    data = scope |> export() |> json_ld("index.html")
    website = typed(data, "WebSite")
    person = typed(data, "Person")

    assert website["@id"] == "https://example.com/#website"
    assert website["url"] == "https://example.com/"
    assert website["name"] == "Ada Lovelace"
    assert website["inLanguage"] == "en"
    assert website["publisher"] == %{"@id" => "https://example.com/#person"}

    assert person["@id"] == "https://example.com/#person"
    assert person["name"] == "Ada Lovelace"
    assert person["url"] == "https://example.com/"
    assert person["description"] == "Writes about <engines>."
    assert person["image"] == "https://example.com/images/#{portrait.public_id}/360.webp"
    assert person["sameAs"] == ["https://github.com/ada"]
  end

  test "a theme without the portrait leaves it out", %{scope: scope} do
    path = test_image_path(600, 600)
    {:ok, _site} = Sites.put_portrait(scope, path, "me.png")
    File.rm(path)

    person = scope |> export() |> json_ld("index.html") |> typed("Person")

    refute Map.has_key?(person, "image")
    refute Map.has_key?(person, "sameAs")
  end

  test "other pages carry no structured data", %{scope: scope} do
    for n <- 1..26, do: post_fixture(scope, %{title: "Post #{n}"})
    page_fixture(scope, %{title: "About", slug: "/about"})
    project_fixture(scope, %{title: "Thing", slug: "/thing"})

    sink = export(scope)

    assert json_ld(sink, "page/2/index.html") == nil
    assert json_ld(sink, "about/index.html") == nil
    assert json_ld(sink, "projects/thing/index.html") == nil
    assert json_ld(sink, "404.html") == nil
  end

  test "text cannot close the script", %{scope: scope} do
    post_fixture(scope, %{title: "</script><b>x</b> & more", slug: "/tricky"})

    sink = export(scope)
    html = RecordingSink.get(sink, "tricky/index.html")

    refute html =~ "</script><b>"

    assert sink |> json_ld("tricky/index.html") |> typed("BlogPosting") |> Map.get("headline") ==
             "</script><b>x</b> & more"
  end

  defp iso8601(datetime),
    do: datetime |> DateTime.truncate(:second) |> DateTime.to_iso8601()
end
