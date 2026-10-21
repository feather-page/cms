defmodule Feather.StaticSite.ExportGeneratedImagesTest do
  use Feather.DataCase

  alias Feather.StaticSite.{Export, GeneratedImages, RecordingSink, Routes}
  alias Vix.Vips.Image, as: VipsImage

  @day ~U[2025-01-01 10:00:00.000000Z]

  setup do
    scope = site_scope_fixture(%{title: "Site", emoji: "🦊"})

    short =
      post_fixture(scope, %{
        title: nil,
        slug: nil,
        publish_at: @day,
        content: [paragraph("A short note.")]
      })

    picture = image_fixture(scope)

    post_fixture(scope, %{
      title: "Pictures",
      slug: "/pictures",
      emoji: "📷",
      publish_at: DateTime.add(@day, 1, :day),
      content: [paragraph("Look."), image_block(picture)]
    })

    %{scope: scope, short: short, picture: picture, sink: export(scope.site)}
  end

  defp export(site, id \\ :export) do
    sink = RecordingSink.new(start_supervised!(RecordingSink, id: id))
    routes = Routes.new(Feather.Repo.reload!(site), canonical_url: "https://example.com/")
    :ok = Export.run(Feather.Repo.reload!(site), routes, sink)
    sink
  end

  defp doc(sink, path), do: sink |> RecordingSink.get(path) |> Floki.parse_document!()

  defp meta(doc, key),
    do: Floki.attribute(doc, ~s(meta[property="#{key}"], meta[name="#{key}"]), "content")

  defp icons(doc), do: Floki.attribute(doc, ~s(link[rel="icon"]), "href")

  defp exported_png(sink, path) do
    assert {:copy, source} = RecordingSink.get(sink, path)
    assert {:ok, image} = VipsImage.new_from_file(source)
    assert {:ok, "pngload"} = VipsImage.header_value(image, "vips-loader")
    {VipsImage.width(image), VipsImage.height(image)}
  end

  test "the export writes the site's emoji as a PNG favicon and links it", c do
    assert [icon] = icons(doc(c.sink, "index.html"))
    assert "/images/" <> name = icon
    assert GeneratedImages.file_name?(name)
    assert exported_png(c.sink, "images/" <> name) == {192, 192}

    assert icons(doc(c.sink, "posts/#{String.downcase(c.short.public_id)}/index.html")) == [icon]
    assert icons(doc(c.sink, "404.html")) == [icon]
  end

  test "a page with its own emoji keeps its inline icon", c do
    assert [icon] = icons(doc(c.sink, "pictures/index.html"))
    assert icon =~ ~r/\Adata:image\/svg\+xml,.*📷/
  end

  test "a short post without an image is shared with a generated card", c do
    post = doc(c.sink, "posts/#{String.downcase(c.short.public_id)}/index.html")

    assert ["https://example.com/images/" <> name] = meta(post, "og:image")
    assert GeneratedImages.file_name?(name)
    assert meta(post, "twitter:card") == ["summary_large_image"]
    assert exported_png(c.sink, "images/" <> name) == {1200, 630}
  end

  test "pages with an image share it and get no card", c do
    post = doc(c.sink, "pictures/index.html")

    assert meta(post, "og:image") == [
             "https://example.com/images/#{c.picture.public_id}/1200.jpg"
           ]
  end

  test "cards differ by title and are rendered once", c do
    home_card = c.sink |> doc("index.html") |> meta("og:image")
    short_post = doc(c.sink, "posts/#{String.downcase(c.short.public_id)}/index.html")

    assert home_card != meta(short_post, "og:image")

    ["https://example.com/images/" <> name] = home_card
    path = GeneratedImages.path(name)
    File.write!(path, "cached")
    on_exit(fn -> File.rm(path) end)

    sink = export(c.scope.site, :again)

    assert RecordingSink.get(sink, "images/" <> name) == {:copy, path}
    assert File.read!(path) == "cached"
  end

  test "a site without an emoji links no favicon and still gets cards" do
    scope = site_scope_fixture(%{title: "Plain", emoji: nil})
    sink = export(scope.site, :plain)
    home = doc(sink, "index.html")

    assert icons(home) == []
    assert ["https://example.com/images/" <> name] = meta(home, "og:image")
    assert exported_png(sink, "images/" <> name) == {1200, 630}
  end
end
