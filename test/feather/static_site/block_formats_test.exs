defmodule Feather.StaticSite.BlockFormatsTest do
  use ExUnit.Case, async: true

  alias Feather.Books.Book
  alias Feather.Content.Blocks, as: ContentBlocks
  alias Feather.Media.Image
  alias Feather.Sites.Site
  alias Feather.StaticSite.{Blocks, MarkdownAlternate, Routes}

  @image %Image{public_id: "img000000001", width: 800, height: 600}

  # One block of every type: a new type fails here until both renderers render it.
  @samples %{
    "paragraph" => %{"type" => "paragraph", "text" => "Text"},
    "header" => %{"type" => "header", "level" => 2, "text" => "Title"},
    "list" => %{"type" => "list", "style" => "ul", "items" => ["Item"]},
    "quote" => %{"type" => "quote", "text" => "Quote", "caption" => "Source"},
    "code" => %{"type" => "code", "code" => "x = 1", "language" => "elixir"},
    "image" => %{"type" => "image", "image_id" => "img000000001", "caption" => "View"},
    "table" => %{"type" => "table", "content" => [["a"]], "with_headings" => false},
    "embed" => %{
      "type" => "embed",
      "source" => "https://www.youtube.com/watch?v=abc",
      "embed" => "https://www.youtube.com/embed/abc"
    },
    "book" => %{"type" => "book", "book_public_id" => "book00000001"},
    "diagram" => %{"type" => "diagram", "code" => "a -> b", "caption" => "Flow"}
  }

  test "every known block type renders to HTML and to Markdown" do
    context =
      Blocks.context(Routes.new(%Site{}, canonical_url: "https://example.com/"),
        content_image_sizes: "100vw",
        image_variants: %{content: [640]},
        images: %{@image.public_id => @image},
        books: %{"book00000001" => %Book{title: "Dune", author: "Frank Herbert"}}
      )

    for type <- ContentBlocks.types() do
      block = Map.fetch!(@samples, type)

      assert Blocks.to_html([block], context) != "", type
      assert MarkdownAlternate.render_blocks([block], context, "https://example.com/") != "", type
    end
  end
end
