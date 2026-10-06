defmodule Feather.Content.BlocksTest do
  use ExUnit.Case, async: true

  alias Feather.Content.Blocks

  @site %{public_id: "SiTe12345678"}

  @blocks [
    %{"id" => "par1", "type" => "paragraph", "text" => "Some <b>bold</b> text."},
    %{"id" => "hdr1", "type" => "header", "level" => 3, "text" => "A section"},
    %{
      "id" => "lst1",
      "type" => "list",
      "style" => "ol",
      "items" => [
        %{
          "content" => "First",
          "items" => [%{"content" => "Nested <i>one</i>", "items" => []}]
        },
        %{"content" => "Second", "items" => []}
      ]
    },
    %{"id" => "lst2", "type" => "list", "style" => "ul", "items" => []},
    %{"id" => "qte1", "type" => "quote", "text" => "Simplicity.", "caption" => "Dijkstra"},
    %{"id" => "cod1", "type" => "code", "code" => "puts \"hello\"\n", "language" => "ruby"},
    %{"id" => "img1", "type" => "image", "image_id" => "DrqGSEC4zyvZ", "caption" => "Inline"},
    %{
      "id" => "tbl1",
      "type" => "table",
      "content" => [["Name", "Value"], ["a", "1"]],
      "with_headings" => true
    },
    %{
      "id" => "emb1",
      "type" => "embed",
      "service" => "youtube",
      "source" => "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      "embed" => "https://www.youtube.com/embed/dQw4w9WgXcQ",
      "width" => 580,
      "height" => 320,
      "caption" => "A video"
    },
    %{
      "id" => "bok1",
      "type" => "book",
      "book_public_id" => "v5ejxZVJ66q8",
      "title" => "The Pragmatic Programmer",
      "author" => "Andrew Hunt, David Thomas",
      "cover_url" => nil,
      "emoji" => "📘"
    }
  ]

  describe "editor.js round trip" do
    test "every block type survives to_editor_js |> from_editor_js unchanged" do
      for block <- @blocks do
        editor_js = Blocks.to_editor_js([block], @site)
        assert Blocks.from_editor_js(editor_js) == [block], "round trip of #{block["type"]}"
      end
    end

    test "the whole content survives a JSON round trip" do
      json = @blocks |> Blocks.to_editor_js(@site) |> Jason.encode!()
      assert Blocks.from_editor_js(json) == @blocks
      assert Blocks.normalize(Jason.decode!(Jason.encode!(@blocks))) == @blocks
    end
  end

  describe "to_editor_js/3" do
    test "renders the Editor.js format" do
      %{"time" => time, "blocks" => blocks} = Blocks.to_editor_js(@blocks, @site)
      assert is_integer(time)

      by_id = Map.new(blocks, &{&1["id"], &1})

      assert by_id["lst1"]["data"]["style"] == "ordered"
      assert by_id["lst2"]["data"]["style"] == "unordered"
      assert by_id["qte1"]["data"]["alignment"] == "left"
      assert by_id["tbl1"]["data"]["withHeadings"] == true

      assert by_id["img1"]["data"] == %{
               "file" => %{"url" => "/sites/SiTe12345678/images/DrqGSEC4zyvZ"},
               "caption" => "Inline",
               "withBorder" => false,
               "stretched" => false,
               "withBackground" => false
             }
    end

    test "book blocks take title, author and emoji from the book" do
      books = %{"v5ejxZVJ66q8" => %{title: "New title", author: "New author", emoji: "📗"}}
      %{"blocks" => [book]} = Blocks.to_editor_js([List.last(@blocks)], @site, books)

      assert book["data"]["title"] == "New title"
      assert book["data"]["author"] == "New author"
      assert book["data"]["emoji"] == "📗"
    end
  end

  describe "from_editor_js/1" do
    test "drops unknown block types and images without an id" do
      data = %{
        "blocks" => [
          %{"id" => "a", "type" => "paragraph", "data" => %{"text" => "Keep"}},
          %{"id" => "b", "type" => "checklist", "data" => %{"items" => []}},
          %{"id" => "c", "type" => "image", "data" => %{"file" => %{"url" => "/nope"}}}
        ]
      }

      assert [%{"id" => "a", "type" => "paragraph", "text" => "Keep"}] =
               Blocks.from_editor_js(data)
    end

    test "applies defaults" do
      data = %{
        "blocks" => [
          %{"id" => "h", "type" => "header", "data" => %{"level" => 1, "text" => "Big"}},
          %{"id" => "c", "type" => "code", "data" => %{"code" => "x"}},
          %{"id" => "l", "type" => "list", "data" => %{"style" => "checklist", "items" => ["a"]}}
        ]
      }

      assert [header, code, list] = Blocks.from_editor_js(data)
      assert header["level"] == 2
      assert code["language"] == "plaintext"
      assert list["style"] == "ul"
      assert list["items"] == [%{"content" => "a", "items" => []}]
    end

    test "parses image ids from full URLs" do
      data = %{
        "blocks" => [
          %{
            "id" => "i",
            "type" => "image",
            "data" => %{
              "file" => %{"url" => "https://cms.example.com/sites/x/images/AbCdEf123456"}
            }
          }
        ]
      }

      assert [%{"image_id" => "AbCdEf123456", "caption" => ""}] = Blocks.from_editor_js(data)
    end

    test "generates missing block ids" do
      [block] = Blocks.from_editor_js(%{"blocks" => [%{"type" => "paragraph", "data" => %{}}]})
      assert block["id"] =~ ~r/\A[0-9a-zA-Z]{10}\z/
    end

    test "handles invalid input" do
      assert Blocks.from_editor_js(nil) == []
      assert Blocks.from_editor_js("not json") == []
      assert Blocks.from_editor_js(%{}) == []
    end
  end

  describe "normalize/1" do
    test "stringifies keys and drops unknown types" do
      assert [%{"id" => "x", "type" => "paragraph", "text" => "Hi"}] =
               Blocks.normalize([
                 %{id: "x", type: "paragraph", text: "Hi"},
                 %{type: "unknown"}
               ])
    end
  end

  describe "sanitizing inline HTML" do
    @payload ~S|<img src=x onerror="window.__xss=1">ok <b>b</b> <i>i</i> <u>u</u> | <>
               ~S|<code>c</code> <a href="https://e.com" onclick="x()">a</a>|
    @clean ~S|ok <b>b</b> <i>i</i> <u>u</u> <code>c</code> <a href="https://e.com">a</a>|

    @dirty_blocks [
      %{"id" => "p", "type" => "paragraph", "text" => @payload},
      %{"id" => "h", "type" => "header", "level" => 2, "text" => @payload},
      %{"id" => "q", "type" => "quote", "text" => @payload, "caption" => @payload},
      %{
        "id" => "l",
        "type" => "list",
        "style" => "ul",
        "items" => [@payload, %{"content" => @payload, "items" => [%{"content" => @payload}]}]
      },
      %{"id" => "t", "type" => "table", "content" => [[@payload, "x"]], "with_headings" => true},
      %{"id" => "i", "type" => "image", "image_id" => "IMAGE1234567", "caption" => @payload},
      %{
        "id" => "e",
        "type" => "embed",
        "service" => "youtube",
        "source" => "javascript:alert(1)",
        "embed" => "javascript:window.__xss=1",
        "caption" => @payload
      }
    ]

    test "normalize/1 sanitizes every inline HTML field" do
      [p, h, q, l, t, i, e] = Blocks.normalize(@dirty_blocks)

      assert p["text"] == @clean
      assert h["text"] == @clean
      assert {q["text"], q["caption"]} == {@clean, @clean}

      assert [
               %{"content" => @clean, "items" => []},
               %{"content" => @clean, "items" => [%{"content" => @clean, "items" => []}]}
             ] = l["items"]

      assert t["content"] == [[@clean, "x"]]
      assert i["caption"] == @clean
      assert e["caption"] == @clean
      assert {e["source"], e["embed"]} == {nil, nil}
    end

    test "keeps safe embed URLs" do
      [e] =
        Blocks.normalize([
          %{
            "type" => "embed",
            "service" => "youtube",
            "source" => "https://www.youtube.com/watch?v=x",
            "embed" => "https://www.youtube.com/embed/x"
          }
        ])

      assert e["source"] == "https://www.youtube.com/watch?v=x"
      assert e["embed"] == "https://www.youtube.com/embed/x"
    end

    test "from_editor_js/1 sanitizes" do
      editor_js = %{
        "blocks" => [
          %{"type" => "paragraph", "data" => %{"text" => @payload}},
          %{"type" => "table", "data" => %{"content" => [[@payload]]}},
          %{"type" => "list", "data" => %{"style" => "ordered", "items" => [@payload]}},
          %{
            "type" => "image",
            "data" => %{
              "file" => %{"url" => "/sites/x/images/IMAGE1234567"},
              "caption" => @payload
            }
          }
        ]
      }

      assert [
               %{"text" => @clean},
               %{"content" => [[@clean]]},
               %{"items" => [%{"content" => @clean}]},
               %{"caption" => @clean}
             ] = Blocks.from_editor_js(editor_js)
    end

    test "to_editor_js/3 sanitizes content stored before sanitizing was in place" do
      %{"blocks" => blocks} = Blocks.to_editor_js(@dirty_blocks, @site)

      json = Jason.encode!(blocks)
      refute json =~ "onerror"
      refute json =~ "javascript:"
      assert json =~ "<b>b</b>"
    end

    test "Editor.js markup passes unchanged" do
      text =
        ~S|It's <b>b</b>&nbsp;<i>i</i> <u class="cdx-underline">u</u> | <>
          ~S|<code class="inline-code">c</code> <a href="https://e.com/?a=1&amp;b=2" | <>
          ~S|target="_blank" rel="nofollow">a</a><br>next &amp; &lt;line&gt;|

      blocks = [%{"id" => "p", "type" => "paragraph", "text" => text}]
      assert Blocks.normalize(blocks) == blocks
    end
  end

  describe "helpers" do
    test "image_ids/1 and book_ids/1" do
      assert Blocks.image_ids(@blocks) == ["DrqGSEC4zyvZ"]
      assert Blocks.book_ids(@blocks) == ["v5ejxZVJ66q8"]
    end

    test "excerpt/2 joins text blocks without HTML" do
      assert Blocks.excerpt(@blocks) == "Some bold text. A section Simplicity."
    end

    test "excerpt/2 truncates with an ellipsis" do
      long = [%{"type" => "paragraph", "text" => String.duplicate("a", 400)}]
      excerpt = Blocks.excerpt(long)
      assert String.length(excerpt) == 300
      assert String.ends_with?(excerpt, "...")
      assert Blocks.excerpt(long, 10) == "aaaaaaa..."
    end

    test "strip_tags/1 keeps whitespace between tags" do
      assert Blocks.strip_tags("<b>a</b> <i>b</i>") == "a b"
      assert Blocks.strip_tags("<b>one</b>\n<i>two</i>") == "one\ntwo"
    end

    test "strip_tags/1 decodes entities and handles plain or broken input" do
      assert Blocks.strip_tags("Tom &amp; Jerry &lt;3") == "Tom & Jerry <3"
      assert Blocks.strip_tags("no tags") == "no tags"
      assert Blocks.strip_tags("") == ""
      assert Blocks.strip_tags("broken <b") == "broken "
    end

    test "strip_tags/1 turns <br> into a space and drops scripts and styles" do
      assert Blocks.strip_tags("line<br>break") == "line break"
      assert Blocks.strip_tags("a<script>alert(1)</script>b<style>p{}</style>c") == "abc"
    end

    test "excerpt/2 keeps words of formatted text apart" do
      blocks = [%{"type" => "paragraph", "text" => "<b>Bold</b> <i>italic</i> words"}]
      assert Blocks.excerpt(blocks) == "Bold italic words"
    end
  end
end
