defmodule Feather.Content.ProseMirrorTest do
  use ExUnit.Case, async: true

  alias Feather.Content.{Blocks, ProseMirror}

  @site %{public_id: "SiTe12345678"}

  @blocks [
    %{
      "id" => "par1",
      "type" => "paragraph",
      "text" =>
        ~S|Some <b>bold</b>, <i>italic</i>, <u>underlined</u> and <code>a &lt; b</code>. | <>
          ~S|<a href="https://e.com/?a=1&amp;b=2">A <b>bold</b> link</a><br>next line|
    },
    %{"id" => "par2", "type" => "paragraph", "text" => ""},
    %{"id" => "hdr1", "type" => "header", "level" => 3, "text" => "A <i>section</i>"},
    %{
      "id" => "lst1",
      "type" => "list",
      "style" => "ol",
      "items" => [
        %{
          "content" => "First",
          "items" => [
            %{
              "content" => "Nested <i>one</i>",
              "items" => [%{"content" => "Deeper", "items" => []}]
            }
          ]
        },
        %{"content" => "Second", "items" => []}
      ]
    },
    %{
      "id" => "lst2",
      "type" => "list",
      "style" => "ul",
      "items" => [%{"content" => "", "items" => []}]
    },
    %{"id" => "qte1", "type" => "quote", "text" => "Simplicity.", "caption" => "Dijkstra"},
    %{"id" => "cod1", "type" => "code", "code" => "puts \"<hello>\"\n", "language" => "ruby"},
    %{"id" => "img1", "type" => "image", "image_id" => "DrqGSEC4zyvZ", "caption" => "Inline"},
    %{
      "id" => "tbl1",
      "type" => "table",
      "content" => [["Name", "<b>Value</b>"], ["a", ""]],
      "with_headings" => true
    },
    %{"id" => "tbl2", "type" => "table", "content" => [["x"]], "with_headings" => false},
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

  defp node_of(doc, id), do: Enum.find(doc["content"], &(&1["attrs"]["id"] == id))

  describe "round trip" do
    test "every block type survives to_doc |> from_doc unchanged" do
      for block <- @blocks do
        doc = ProseMirror.to_doc([block], @site)
        assert ProseMirror.from_doc(doc) == [block], "round trip of #{block["id"]}"
      end
    end

    test "the whole content survives a JSON round trip" do
      json = @blocks |> ProseMirror.to_doc(@site) |> Jason.encode!()
      assert json |> Jason.decode!() |> ProseMirror.from_doc() == @blocks
    end

    test "single top-level nodes convert with from_node/1" do
      doc = ProseMirror.to_doc(@blocks, @site)
      assert Enum.map(doc["content"], &ProseMirror.from_node/1) == @blocks
      assert ProseMirror.from_node(%{"type" => "horizontal_rule"}) == nil
    end
  end

  describe "to_doc/3" do
    test "renders a doc whose top-level nodes carry the block ids" do
      doc = ProseMirror.to_doc(@blocks, @site)

      assert doc["type"] == "doc"
      assert Enum.map(doc["content"], & &1["attrs"]["id"]) == Enum.map(@blocks, & &1["id"])
    end

    test "turns inline HTML into text with marks and hard breaks" do
      [par] = ProseMirror.to_doc([hd(@blocks)], @site)["content"]

      assert par == %{
               "type" => "paragraph",
               "attrs" => %{"id" => "par1"},
               "content" => [
                 %{"type" => "text", "text" => "Some "},
                 %{"type" => "text", "text" => "bold", "marks" => [%{"type" => "bold"}]},
                 %{"type" => "text", "text" => ", "},
                 %{"type" => "text", "text" => "italic", "marks" => [%{"type" => "italic"}]},
                 %{"type" => "text", "text" => ", "},
                 %{
                   "type" => "text",
                   "text" => "underlined",
                   "marks" => [%{"type" => "underline"}]
                 },
                 %{"type" => "text", "text" => " and "},
                 %{"type" => "text", "text" => "a < b", "marks" => [%{"type" => "code"}]},
                 %{"type" => "text", "text" => ". "},
                 %{
                   "type" => "text",
                   "text" => "A ",
                   "marks" => [link_mark("https://e.com/?a=1&b=2")]
                 },
                 %{
                   "type" => "text",
                   "text" => "bold",
                   "marks" => [link_mark("https://e.com/?a=1&b=2"), %{"type" => "bold"}]
                 },
                 %{
                   "type" => "text",
                   "text" => " link",
                   "marks" => [link_mark("https://e.com/?a=1&b=2")]
                 },
                 %{"type" => "hard_break"},
                 %{"type" => "text", "text" => "next line"}
               ]
             }
    end

    test "renders the node of every block type" do
      doc = ProseMirror.to_doc(@blocks, @site)

      assert node_of(doc, "par2") == %{"type" => "paragraph", "attrs" => %{"id" => "par2"}}
      assert node_of(doc, "hdr1")["attrs"] == %{"id" => "hdr1", "level" => 3}

      assert node_of(doc, "lst1") == %{
               "type" => "ordered_list",
               "attrs" => %{"id" => "lst1"},
               "content" => [
                 %{
                   "type" => "list_item",
                   "content" => [
                     paragraph("First"),
                     %{
                       "type" => "ordered_list",
                       "content" => [
                         %{
                           "type" => "list_item",
                           "content" => [
                             %{
                               "type" => "paragraph",
                               "content" => [
                                 %{"type" => "text", "text" => "Nested "},
                                 %{
                                   "type" => "text",
                                   "text" => "one",
                                   "marks" => [%{"type" => "italic"}]
                                 }
                               ]
                             },
                             %{
                               "type" => "ordered_list",
                               "content" => [
                                 %{"type" => "list_item", "content" => [paragraph("Deeper")]}
                               ]
                             }
                           ]
                         }
                       ]
                     }
                   ]
                 },
                 %{"type" => "list_item", "content" => [paragraph("Second")]}
               ]
             }

      assert node_of(doc, "lst2")["type"] == "bullet_list"

      assert node_of(doc, "qte1") == %{
               "type" => "quote",
               "attrs" => %{"id" => "qte1"},
               "content" => [
                 %{"type" => "quote_text", "content" => [text("Simplicity.")]},
                 %{"type" => "quote_caption", "content" => [text("Dijkstra")]}
               ]
             }

      assert node_of(doc, "cod1") == %{
               "type" => "code_block",
               "attrs" => %{"id" => "cod1", "language" => "ruby"},
               "content" => [text("puts \"<hello>\"\n")]
             }

      assert node_of(doc, "img1") == %{
               "type" => "image",
               "attrs" => %{
                 "id" => "img1",
                 "image_id" => "DrqGSEC4zyvZ",
                 "src" => "/sites/SiTe12345678/images/DrqGSEC4zyvZ"
               },
               "content" => [text("Inline")]
             }

      assert node_of(doc, "tbl1") == %{
               "type" => "table",
               "attrs" => %{"id" => "tbl1"},
               "content" => [
                 %{
                   "type" => "table_row",
                   "content" => [
                     %{"type" => "table_header", "content" => [text("Name")]},
                     %{
                       "type" => "table_header",
                       "content" => [
                         %{"type" => "text", "text" => "Value", "marks" => [%{"type" => "bold"}]}
                       ]
                     }
                   ]
                 },
                 %{
                   "type" => "table_row",
                   "content" => [
                     %{"type" => "table_cell", "content" => [text("a")]},
                     %{"type" => "table_cell"}
                   ]
                 }
               ]
             }

      assert node_of(doc, "emb1") == %{
               "type" => "embed",
               "attrs" => %{
                 "id" => "emb1",
                 "service" => "youtube",
                 "source" => "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                 "embed" => "https://www.youtube.com/embed/dQw4w9WgXcQ",
                 "width" => 580,
                 "height" => 320
               },
               "content" => [text("A video")]
             }

      assert node_of(doc, "bok1") == %{
               "type" => "book",
               "attrs" => %{
                 "id" => "bok1",
                 "book_public_id" => "v5ejxZVJ66q8",
                 "title" => "The Pragmatic Programmer",
                 "author" => "Andrew Hunt, David Thomas",
                 "cover_url" => nil,
                 "emoji" => "📘"
               }
             }
    end

    test "book nodes take title, author and emoji from the book" do
      books = %{"v5ejxZVJ66q8" => %{title: "New title", author: "New author", emoji: "📗"}}
      [book] = ProseMirror.to_doc([List.last(@blocks)], @site, books)["content"]

      assert %{"title" => "New title", "author" => "New author", "emoji" => "📗"} =
               book["attrs"]
    end

    test "an empty table gets one empty cell to type in" do
      [table] =
        ProseMirror.to_doc([%{"id" => "t", "type" => "table", "content" => []}], @site)[
          "content"
        ]

      assert table["content"] == [
               %{"type" => "table_row", "content" => [%{"type" => "table_cell"}]}
             ]
    end

    test "Editor.js markup becomes plain marks" do
      text =
        ~S|<u class="cdx-underline">u</u> <code class="inline-code">c</code> | <>
          ~S|<a href="https://e.com" target="_blank" rel="nofollow">a</a>|

      [par] = ProseMirror.to_doc([%{"type" => "paragraph", "text" => text}], @site)["content"]

      assert [
               %{"marks" => [%{"type" => "underline"}]},
               _,
               %{"marks" => [%{"type" => "code"}]},
               _,
               %{
                 "marks" => [
                   %{
                     "type" => "link",
                     "attrs" => %{
                       "href" => "https://e.com",
                       "target" => "_blank",
                       "rel" => "nofollow"
                     }
                   }
                 ]
               }
             ] = par["content"]

      assert [%{"text" => converted}] = ProseMirror.from_doc(%{"content" => [par]})

      assert converted ==
               ~S|<u>u</u> <code>c</code> | <>
                 ~S|<a href="https://e.com" target="_blank" rel="nofollow">a</a>|
    end
  end

  describe "from_doc/1" do
    test "nests overlapping marks in a fixed order" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "paragraph",
            "attrs" => %{"id" => "p"},
            "content" => [
              %{"type" => "text", "text" => "a", "marks" => [%{"type" => "bold"}]},
              %{
                "type" => "text",
                "text" => "b",
                "marks" => [%{"type" => "italic"}, %{"type" => "bold"}]
              },
              %{"type" => "text", "text" => "c", "marks" => [%{"type" => "italic"}]}
            ]
          }
        ]
      }

      assert [%{"text" => "<b>a<i>b</i></b><i>c</i>"}] = ProseMirror.from_doc(doc)
    end

    test "drops unknown nodes and marks, generates missing ids, accepts nil" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{"type" => "horizontal_rule", "attrs" => %{"id" => "x"}},
          %{
            "type" => "paragraph",
            "content" => [%{"type" => "text", "text" => "t", "marks" => [%{"type" => "strike"}]}]
          },
          %{"type" => "image", "attrs" => %{"id" => "i"}}
        ]
      }

      assert [%{"type" => "paragraph", "text" => "t", "id" => id}] = ProseMirror.from_doc(doc)
      assert is_binary(id) and id != ""
      assert ProseMirror.from_doc(nil) == []
      assert ProseMirror.from_doc(%{"type" => "doc"}) == []
    end

    test "applies the defaults of the block list" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{"type" => "heading", "attrs" => %{"id" => "h", "level" => 1}},
          %{"type" => "code_block", "attrs" => %{"id" => "c"}}
        ]
      }

      assert [
               %{"type" => "header", "level" => 2, "text" => ""},
               %{"type" => "code", "code" => "", "language" => "plaintext"}
             ] = ProseMirror.from_doc(doc)
    end
  end

  describe "sanitizing" do
    @payload ~S|<img src=x onerror="window.__xss=1">ok <b>b</b> <a href="javascript:x()">a</a>|

    test "to_doc/3 sanitizes content stored before sanitizing was in place" do
      json =
        [%{"id" => "p", "type" => "paragraph", "text" => @payload}]
        |> ProseMirror.to_doc(@site)
        |> Jason.encode!()

      refute json =~ "onerror"
      refute json =~ "javascript:"
      refute json =~ "img"
    end

    test "from_doc/1 sanitizes text, link targets and embed URLs" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{"type" => "paragraph", "attrs" => %{"id" => "p"}, "content" => [text(@payload)]},
          %{
            "type" => "paragraph",
            "attrs" => %{"id" => "l"},
            "content" => [
              %{
                "type" => "text",
                "text" => "a",
                "marks" => [link_mark("javascript:alert(1)")]
              }
            ]
          },
          %{
            "type" => "embed",
            "attrs" => %{
              "id" => "e",
              "service" => "youtube",
              "source" => "javascript:alert(1)",
              "embed" => "javascript:window.__xss=1"
            },
            "content" => [text(@payload)]
          }
        ]
      }

      escaped =
        ~S|&lt;img src=x onerror="window.__xss=1"&gt;ok &lt;b&gt;b&lt;/b&gt; | <>
          ~S|&lt;a href="javascript:x()"&gt;a&lt;/a&gt;|

      assert [p, l, e] = ProseMirror.from_doc(doc)
      assert p["text"] == escaped
      assert l["text"] == "<a>a</a>"
      assert e["caption"] == escaped
      assert {e["source"], e["embed"]} == {nil, nil}
      assert Blocks.normalize([p, l, e]) == [p, l, e]
    end
  end

  defp text(text), do: %{"type" => "text", "text" => text}
  defp paragraph(text), do: %{"type" => "paragraph", "content" => [text(text)]}

  defp link_mark(href),
    do: %{"type" => "link", "attrs" => %{"href" => href, "target" => nil, "rel" => nil}}
end
