defmodule Feather.StaticSite.BlocksTest do
  use ExUnit.Case, async: true

  alias Feather.Books.Book
  alias Feather.Media.Image
  alias Feather.Sites.Site
  alias Feather.StaticSite.{Blocks, Routes}

  @image %Image{public_id: "img000000001", width: 800, height: 600}
  @cover %Image{public_id: "cov000000001", width: 200, height: 300}
  @diagram String.duplicate("d1", 32) <> ".svg"

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

    %{
      context:
        Blocks.context(routes,
          images: %{@image.public_id => @image},
          books: books,
          diagrams: %{"a -> b" => @diagram},
          content_image_sizes: "(min-width: 40rem) 30rem, 100vw",
          book_cover_sizes: "80px",
          image_variants: %{content: [430, 640, 960], book_cover: [180, 360]}
        )
    }
  end

  defp html(block, context), do: Blocks.to_html([block], context)

  test "paragraph", %{context: c} do
    assert html(%{"type" => "paragraph", "text" => "Hi <b>you</b><script>x</script>"}, c) ==
             "<p>Hi <b>you</b></p>"
  end

  test "a paragraph keeps its line breaks", %{context: c} do
    assert html(%{"type" => "paragraph", "text" => "Line one<br>line two"}, c) ==
             "<p>Line one<br>line two</p>"
  end

  test "a paragraph without text renders nothing", %{context: c} do
    for text <- ["", "  ", "<br>", "<b> </b>", "&nbsp;", nil] do
      assert html(%{"type" => "paragraph", "text" => text}, c) == "", inspect(text)
    end
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

    assert html(%{"type" => "list", "style" => "ul", "items" => ["a"]}, c) ==
             "<ul><li>a</li></ul>"

    assert html(%{"type" => "list", "style" => "ul", "items" => []}, c) == ""
  end

  test "quote with and without caption", %{context: c} do
    assert html(%{"type" => "quote", "text" => "Simple.", "caption" => "Dijkstra"}, c) ==
             "<blockquote><p>Simple.</p><cite>Dijkstra</cite></blockquote>"

    assert html(%{"type" => "quote", "text" => "Simple.", "caption" => ""}, c) ==
             "<blockquote><p>Simple.</p></blockquote>"
  end

  test "code is escaped and labelled with its language", %{context: c} do
    assert html(%{"type" => "code", "code" => "<b>\"x\" & y</b>\n", "language" => "html"}, c) ==
             ~s(<pre data-language="html"><code class="language-html">) <>
               "&lt;b&gt;&quot;x&quot; &amp; y&lt;/b&gt;\n</code></pre>"
  end

  test "diagram renders as a figure with the image and caption", %{context: c} do
    block = %{"type" => "diagram", "code" => "a -> b", "caption" => "A <b>flow</b>"}

    assert html(block, c) ==
             ~s(<figure class="diagram"><img loading="lazy" src="/diagrams/#{@diagram}" alt="A flow">) <>
               ~s(<figcaption>A <b>flow</b></figcaption></figure>)

    assert html(%{block | "caption" => ""}, c) ==
             ~s(<figure class="diagram"><img loading="lazy" src="/diagrams/#{@diagram}" alt="Diagram"></figure>)
  end

  test "a diagram that was not rendered shows its source as d2 code", %{context: c} do
    assert html(%{"type" => "diagram", "code" => "a -> <b>", "caption" => "Flow"}, c) ==
             ~s(<pre data-language="d2"><code class="language-d2">a -&gt; &lt;b&gt;</code></pre>)

    assert html(%{"type" => "diagram", "code" => " \n", "caption" => "Flow"}, c) == ""
  end

  test "highlighted code keeps its pre, code and language label", %{context: c} do
    spans = ~s(<span class="hl-k">puts</span> <span class="hl-s">&#34;x&#34;</span>)
    c = %{c | highlights: %{{~s(puts "x"), "ruby"} => spans}}

    assert html(%{"type" => "code", "code" => ~s(puts "x"), "language" => "ruby"}, c) ==
             ~s(<pre data-language="ruby"><code class="language-ruby">#{spans}</code></pre>)

    assert html(%{"type" => "code", "code" => "puts 2", "language" => "ruby"}, c) ==
             ~s(<pre data-language="ruby"><code class="language-ruby">puts 2</code></pre>)
  end

  test "code without a meaningful language has no label", %{context: c} do
    for language <- ["plaintext", "text", "", nil, "wdt_reset(); ```", ~S|x" onclick="y|] do
      assert html(%{"type" => "code", "code" => "x", "language" => language}, c) ==
               "<pre><code>x</code></pre>"
    end
  end

  test "image in a figure with the content variants narrowest first, sizes, size, alt and caption",
       %{context: c} do
    block = %{"type" => "image", "image_id" => "img000000001", "caption" => "A <b>nice</b> view"}

    assert html(block, c) ==
             ~s(<figure><img loading="lazy" height="600" width="800" ) <>
               ~s(src="/images/img000000001/430.webp" ) <>
               ~s(srcset="/images/img000000001/430.webp 430w, /images/img000000001/640.webp 640w, ) <>
               ~s(/images/img000000001/960.webp 800w" ) <>
               ~s|sizes="(min-width: 40rem) 30rem, 100vw" | <>
               ~s(alt="A nice view" />) <>
               ~s(<figcaption>A <b>nice</b> view</figcaption></figure>)
  end

  test "image without caption has an empty alt and no figcaption", %{context: c} do
    output = html(%{"type" => "image", "image_id" => "img000000001", "caption" => ""}, c)
    assert output =~ ~s(alt="")
    assert output =~ ~r{\A<figure><img [^>]*/></figure>\z}
    refute output =~ "figcaption"
  end

  test "image of an unknown image renders nothing", %{context: c} do
    assert html(%{"type" => "image", "image_id" => "missing00001"}, c) == ""
  end

  test "table with and without headings", %{context: c} do
    content = [["Name", "<b>Value</b>"], ["a", "1"]]

    assert html(%{"type" => "table", "content" => content, "with_headings" => true}, c) ==
             "<table><thead><tr><th>Name</th><th><b>Value</b></th></tr></thead>" <>
               "<tbody><tr><td>a</td><td>1</td></tr></tbody></table>"

    assert html(%{"type" => "table", "content" => content, "with_headings" => false}, c) ==
             "<table><tbody><tr><td>Name</td><td><b>Value</b></td></tr>" <>
               "<tr><td>a</td><td>1</td></tr></tbody></table>"
  end

  test "embed uses youtube-nocookie, a title and its size as aspect ratio", %{context: c} do
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
             ~s(<figure class="embed"><iframe src="https://www.youtube-nocookie.com/embed/abc" ) <>
               ~s(title="A video" width="580" height="320" style="aspect-ratio: 580 / 320" ) <>
               ~s(allowfullscreen></iframe><figcaption>A video</figcaption></figure>)
  end

  test "embed without a numeric size or caption keeps the default ratio", %{context: c} do
    block = %{
      "type" => "embed",
      "embed" => "https://player.vimeo.com/video/1",
      "width" => "100%",
      "caption" => " "
    }

    assert html(block, c) ==
             ~s(<figure class="embed"><iframe src="https://player.vimeo.com/video/1" ) <>
               ~s(title="Embedded content" width="100%" allowfullscreen></iframe></figure>)
  end

  test "embed with an unsafe URL or size is not injected", %{context: c} do
    assert html(%{"type" => "embed", "embed" => "javascript:alert(1)"}, c) == ""

    output =
      html(
        %{"type" => "embed", "embed" => "https://e.com/x", "width" => ~S|1" onload="x|},
        c
      )

    assert output ==
             ~s(<figure class="embed"><iframe src="https://e.com/x" title="Embedded content" ) <>
               ~s(allowfullscreen></iframe></figure>)
  end

  test "book card with emoji, escaped", %{context: c} do
    assert html(%{"type" => "book", "book_public_id" => "book00000001"}, c) ==
             ~s(<figure class="book-card book-card--detail">) <>
               ~s(<span class="book-emoji">📘</span><figcaption class="book-info">) <>
               ~s(<cite class="book-title">Dune &amp; More</cite>) <>
               ~s(<span class="book-author">Frank Herbert</span></figcaption></figure>)
  end

  test "book card prefers the cover, with its variants, size and loaded lazily", %{context: c} do
    output = html(%{"type" => "book", "book_public_id" => "book00000002"}, c)

    assert output =~
             ~s(<img src="/images/cov000000001/180.webp" ) <>
               ~s(srcset="/images/cov000000001/180.webp 120w, /images/cov000000001/360.webp 200w" ) <>
               ~s(sizes="80px" alt="" class="book-cover" width="200" height="300" loading="lazy">)

    refute output =~ "book-emoji"
  end

  test "without inline images, images render nothing and a book card shows no cover",
       %{context: c} do
    c = %{c | inline_images: false}

    assert html(%{"type" => "image", "image_id" => @image.public_id, "caption" => "Hi"}, c) == ""

    output = html(%{"type" => "book", "book_public_id" => "book00000002"}, c)
    assert output =~ ~s(<span class="book-emoji">📗</span>)
    refute output =~ "<img"
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
