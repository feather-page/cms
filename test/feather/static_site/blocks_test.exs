defmodule Feather.StaticSite.BlocksTest do
  use ExUnit.Case, async: true

  alias Feather.Books.Book
  alias Feather.Media.Image
  alias Feather.Sites.Site
  alias Feather.StaticSite.{Blocks, Routes}

  @image %Image{public_id: "img000000001", width: 800, height: 600}
  @cover %Image{public_id: "cov000000001", width: 200, height: 300}

  setup do
    routes = Routes.new(%Site{public_id: "site00000001"})

    books = %{
      "book00000001" => %Book{
        public_id: "book00000001",
        title: "Dune & More",
        author: "Frank Herbert",
        emoji: "📘",
        cover_image: nil
      },
      "book00000002" => %Book{
        public_id: "book00000002",
        title: "Covered",
        author: "A. Author",
        emoji: "📗",
        cover_image: @cover
      }
    }

    %{context: Blocks.context(routes, %{@image.public_id => @image}, books)}
  end

  defp html(block, context), do: Blocks.to_html([block], context)

  test "paragraph", %{context: c} do
    assert html(%{"type" => "paragraph", "text" => "Hi <b>you</b><script>x</script>"}, c) ==
             "<p>Hi <b>you</b></p>"
  end

  test "header with levels 2 to 4, others become 2", %{context: c} do
    assert html(%{"type" => "header", "level" => 3, "text" => "A <i>title</i>"}, c) ==
             "<h3>A <i>title</i></h3>"

    assert html(%{"type" => "header", "level" => 1, "text" => "x"}, c) == "<h2>x</h2>"
  end

  test "nested list keeps the block style", %{context: c} do
    block = %{
      "type" => "list",
      "style" => "ol",
      "items" => [
        %{"content" => "First", "items" => [%{"content" => "Nested <i>one</i>", "items" => []}]},
        %{"content" => "Second", "items" => []}
      ]
    }

    assert html(block, c) ==
             "<ol><li>First<ol><li>Nested <i>one</i></li></ol></li><li>Second</li></ol>"

    assert html(%{"type" => "list", "style" => "ul", "items" => ["a"]}, c) == "<ul><li>a</li></ul>"
    assert html(%{"type" => "list", "style" => "ul", "items" => []}, c) == ""
  end

  test "quote with and without caption", %{context: c} do
    assert html(%{"type" => "quote", "text" => "Simple.", "caption" => "Dijkstra"}, c) ==
             "<blockquote><p>Simple.</p><cite>Dijkstra</cite></blockquote>"

    assert html(%{"type" => "quote", "text" => "Simple.", "caption" => ""}, c) ==
             "<blockquote><p>Simple.</p></blockquote>"
  end

  test "code is escaped", %{context: c} do
    assert html(%{"type" => "code", "code" => "<b>\"x\" & y</b>\n", "language" => "html"}, c) ==
             "<pre><code>&lt;b&gt;&quot;x&quot; &amp; y&lt;/b&gt;\n</code></pre>"
  end

  test "image with srcset, size, alt and caption", %{context: c} do
    block = %{"type" => "image", "image_id" => "img000000001", "caption" => "A <b>nice</b> view"}

    assert html(block, c) ==
             ~s(<picture><source srcset="/images/img000000001/mobile_x1.webp 430w, ) <>
               ~s(/images/img000000001/mobile_x2.webp 860w, ) <>
               ~s(/images/img000000001/desktop_x1.webp 1000w, ) <>
               ~s(/images/img000000001/mobile_x3.webp 1290w, ) <>
               ~s(/images/img000000001/desktop_x2.webp 2000w" type="image/webp">) <>
               ~s(<img loading="lazy" height="600" width="800" ) <>
               ~s(src="/images/img000000001/desktop_x1.jpg" alt="A nice view" />) <>
               ~s(<figcaption>A <b>nice</b> view</figcaption></picture>)
  end

  test "image without caption has an empty alt and no figcaption", %{context: c} do
    output = html(%{"type" => "image", "image_id" => "img000000001", "caption" => ""}, c)
    assert output =~ ~s(alt="")
    refute output =~ "figcaption"
  end

  test "image of an unknown image renders nothing", %{context: c} do
    assert html(%{"type" => "image", "image_id" => "missing00001"}, c) == ""
  end

  test "table with and without headings", %{context: c} do
    content = [["Name", "<b>Value</b>"], ["a", "1"]]

    assert html(%{"type" => "table", "content" => content, "with_headings" => true}, c) ==
             "<table><thead><tr><td>Name</td><td><b>Value</b></td></tr></thead>" <>
               "<tbody><tr><td>a</td><td>1</td></tr></tbody></table>"

    assert html(%{"type" => "table", "content" => content, "with_headings" => false}, c) ==
             "<table><tbody><tr><td>Name</td><td><b>Value</b></td></tr>" <>
               "<tr><td>a</td><td>1</td></tr></tbody></table>"
  end

  test "embed uses youtube-nocookie and size attributes", %{context: c} do
    block = %{
      "type" => "embed",
      "service" => "youtube",
      "source" => "https://www.youtube.com/watch?v=abc",
      "embed" => "https://www.youtube.com/embed/abc",
      "width" => 580,
      "height" => "320",
      "caption" => "A video"
    }

    assert html(block, c) ==
             ~s(<figure><iframe src="https://www.youtube-nocookie.com/embed/abc" width="580" ) <>
               ~s(height="320" frameborder="0" allowfullscreen></iframe>) <>
               ~s(<figcaption>A video</figcaption></figure>)
  end

  test "embed with an unsafe URL or size is not injected", %{context: c} do
    assert html(%{"type" => "embed", "embed" => "javascript:alert(1)"}, c) == ""

    output =
      html(
        %{"type" => "embed", "embed" => "https://e.com/x", "width" => ~S|1" onload="x|},
        c
      )

    assert output ==
             ~s(<figure><iframe src="https://e.com/x" frameborder="0" allowfullscreen></iframe></figure>)
  end

  test "book card with emoji, escaped", %{context: c} do
    assert html(%{"type" => "book", "book_public_id" => "book00000001"}, c) ==
             ~s(<div class="book-card book-card--detail"><div class="book-card-header">) <>
               ~s(<span class="book-emoji">📘</span><div class="book-info">) <>
               ~s(<div class="book-title">Dune &amp; More</div>) <>
               ~s(<div class="book-author">Frank Herbert</div></div></div></div>)
  end

  test "book card prefers the cover", %{context: c} do
    output = html(%{"type" => "book", "book_public_id" => "book00000002"}, c)

    assert output =~
             ~s(<img src="/images/cov000000001/mobile_x1.webp" alt="Covered" class="book-cover">)

    refute output =~ "book-emoji"
  end

  test "unknown books and block types render nothing", %{context: c} do
    assert html(%{"type" => "book", "book_public_id" => "nope"}, c) == ""
    assert Blocks.to_html([%{"type" => "unknown"}, nil], c) == ""
  end

  test "blocks are concatenated", %{context: c} do
    blocks = [
      %{"type" => "paragraph", "text" => "a"},
      %{"type" => "paragraph", "text" => "b"}
    ]

    assert Blocks.to_html(blocks, c) == "<p>a</p><p>b</p>"
  end
end
