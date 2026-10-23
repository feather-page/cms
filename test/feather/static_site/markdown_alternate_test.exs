defmodule Feather.StaticSite.MarkdownAlternateTest do
  use ExUnit.Case, async: true

  alias Feather.Books.Book
  alias Feather.Content.{Page, Post, Project}
  alias Feather.Media.Image
  alias Feather.Sites.Site
  alias Feather.StaticSite.{Blocks, MarkdownAlternate, Routes, SiteData}

  @image %Image{public_id: "img000000001", width: 800, height: 600}
  @review %Post{public_id: "rev000000001", slug: "/dune"}
  @url "https://example.com/hello/"

  setup do
    routes = Routes.canonical(Routes.new(%Site{}, canonical_url: "https://example.com/"))

    books = %{
      "book00000001" => %Book{title: "Dune & More", author: "Frank Herbert", post: nil},
      "book00000002" => %Book{title: "Dune", author: "Frank Herbert", rating: 4, post: @review}
    }

    context =
      Blocks.context(routes,
        content_image_sizes: "100vw",
        image_variants: %{content: [430, 640, 960]},
        images: %{@image.public_id => @image},
        books: books
      )

    %{routes: routes, context: context}
  end

  defp markdown(block, context), do: MarkdownAlternate.render_blocks([block], context, @url)

  describe "blocks" do
    test "a paragraph converts its inline HTML, links resolved against the page", %{context: c} do
      block = %{"type" => "paragraph", "text" => ~S|A <b>bold</b> <a href="next/">move</a>.|}

      assert markdown(block, c) == "A **bold** [move](https://example.com/hello/next/)."
      assert markdown(%{"type" => "paragraph", "text" => "<br> "}, c) == ""
    end

    test "a header keeps its level, on one line", %{context: c} do
      assert markdown(%{"type" => "header", "level" => 3, "text" => "A <i>title</i>"}, c) ==
               "### A *title*"

      assert markdown(%{"type" => "header", "level" => 4, "text" => "One<br>line"}, c) ==
               "#### One line"

      assert markdown(%{"type" => "header", "level" => 2, "text" => "Ranked #"}, c) ==
               "## Ranked \\#"

      assert markdown(%{"type" => "header", "level" => 2, "text" => "C#"}, c) == "## C#"
    end

    test "a list becomes a nested Markdown list", %{context: c} do
      block = %{
        "type" => "list",
        "style" => "ol",
        "items" => [
          %{"content" => "First<br>line", "items" => [%{"content" => "Nested", "items" => []}]},
          %{"content" => "- Second", "items" => []}
        ]
      }

      assert markdown(block, c) == "1. First\\\n   line\n   1. Nested\n2. \\- Second"

      assert markdown(%{"type" => "list", "style" => "ul", "items" => ["a", "<i>b</i>"]}, c) ==
               "- a\n- *b*"

      assert markdown(%{"type" => "list", "style" => "ul", "items" => []}, c) == ""
    end

    test "a list leaves out empty items, an item with only nested items starts with its list",
         %{context: c} do
      items = [
        %{"content" => "a", "items" => [%{"content" => "", "items" => []}, "b"]},
        %{"content" => " <br>", "items" => [%{"content" => "&nbsp;", "items" => []}]},
        %{"content" => "", "items" => ["c"]}
      ]

      assert markdown(%{"type" => "list", "style" => "ul", "items" => items}, c) ==
               "- a\n  - b\n- - c"

      assert markdown(%{"type" => "list", "style" => "ol", "items" => items}, c) ==
               "1. a\n   1. b\n2. 1. c"
    end

    test "a list right after a list of its style takes the other markers", %{context: c} do
      ul = %{"type" => "list", "style" => "ul", "items" => ["a", "b"]}
      ol = %{"type" => "list", "style" => "ol", "items" => ["a", "b"]}

      nested = %{
        "type" => "list",
        "style" => "ul",
        "items" => [%{"content" => "a", "items" => ["n"]}]
      }

      empty = %{"type" => "paragraph", "text" => ""}
      text = %{"type" => "paragraph", "text" => "x"}

      assert MarkdownAlternate.render_blocks([ul, nested, empty, ul, text, ul], c, @url) ==
               "- a\n- b\n\n* a\n  * n\n\n- a\n- b\n\nx\n\n- a\n- b"

      assert MarkdownAlternate.render_blocks([ol, ol, ol, ul, ol], c, @url) ==
               "1. a\n2. b\n\n1) a\n2) b\n\n1. a\n2. b\n\n- a\n- b\n\n1. a\n2. b"
    end

    test "a quote becomes a blockquote with its source as the last line", %{context: c} do
      assert markdown(
               %{"type" => "quote", "text" => "Simple.<br>True.", "caption" => "Dijkstra"},
               c
             ) ==
               "> Simple.\\\n> True.\n>\n> — Dijkstra"

      assert markdown(%{"type" => "quote", "text" => "Simple.", "caption" => ""}, c) ==
               "> Simple."
    end

    test "code becomes a fenced block with its language, unhighlighted", %{context: c} do
      c = %{c | highlights: %{{"<b>x</b>", "html"} => "<span>highlighted</span>"}}

      assert markdown(%{"type" => "code", "code" => "<b>x</b>", "language" => "html"}, c) ==
               "```html\n<b>x</b>\n```"

      assert markdown(%{"type" => "code", "code" => "x\n", "language" => "plaintext"}, c) ==
               "```\nx\n```"

      assert markdown(%{"type" => "code", "code" => "a ```` b", "language" => "md"}, c) ==
               "`````md\na ```` b\n`````"
    end

    test "an image links its largest content variant with the caption as alt text",
         %{context: c} do
      block = %{
        "type" => "image",
        "image_id" => @image.public_id,
        "caption" => "A <b>[nice]</b> view"
      }

      assert markdown(block, c) ==
               "![A \\[nice\\] view](https://example.com/images/img000000001/960.webp)"

      assert markdown(%{"type" => "image", "image_id" => "missing00001"}, c) == ""
    end

    test "a table becomes a GitHub table, with an empty header row without headings",
         %{context: c} do
      content = [["Name", "<b>Value</b>"], ["a|b", "1<br>2"], ["c"]]

      assert markdown(%{"type" => "table", "content" => content, "with_headings" => true}, c) ==
               "| Name | **Value** |\n| --- | --- |\n| a\\|b | 1<br>2 |\n| c |  |"

      assert markdown(%{"type" => "table", "content" => [["a"]], "with_headings" => false}, c) ==
               "|  |\n| --- |\n| a |"

      assert markdown(%{"type" => "table", "content" => [], "with_headings" => true}, c) == ""
    end

    test "an embed becomes a link to its source with the caption", %{context: c} do
      block = %{
        "type" => "embed",
        "source" => "https://www.youtube.com/watch?v=abc",
        "embed" => "https://www.youtube.com/embed/abc",
        "caption" => "A <i>video</i>"
      }

      assert markdown(block, c) == "[A video](https://www.youtube.com/watch?v=abc)"

      assert markdown(%{"type" => "embed", "embed" => "https://player.vimeo.com/video/1"}, c) ==
               "[Embedded content](https://player.vimeo.com/video/1)"

      assert markdown(%{"type" => "embed", "embed" => "javascript:alert(1)"}, c) == ""
    end

    test "a book shows title, author, rating and a link to its review", %{context: c} do
      assert markdown(%{"type" => "book", "book_public_id" => "book00000002"}, c) ==
               "[*Dune*](https://example.com/dune/) · Frank Herbert · 4 of 5 stars"

      assert markdown(%{"type" => "book", "book_public_id" => "book00000001"}, c) ==
               "*Dune & More* · Frank Herbert"

      assert markdown(%{"type" => "book", "book_public_id" => "missing00001"}, c) == ""
    end

    test "a diagram shows its D2 source in a fenced block with the caption", %{context: c} do
      c = %{c | diagrams: %{"a -> b" => String.duplicate("d1", 32) <> ".svg"}}

      assert markdown(%{"type" => "diagram", "code" => "a -> b", "caption" => "A <b>flow</b>"}, c) ==
               "```d2\na -> b\n```\n\nA **flow**"

      assert markdown(%{"type" => "diagram", "code" => "a -> b", "caption" => ""}, c) ==
               "```d2\na -> b\n```"

      assert markdown(%{"type" => "diagram", "code" => " ", "caption" => "Flow"}, c) == ""
    end

    test "blocks are separated by a blank line, unknown ones dropped", %{context: c} do
      blocks = [
        %{"type" => "paragraph", "text" => "a"},
        %{"type" => "unknown"},
        %{"type" => "paragraph", "text" => ""},
        %{"type" => "paragraph", "text" => "b"}
      ]

      assert MarkdownAlternate.render_blocks(blocks, c, @url) == "a\n\nb"
    end
  end

  describe "render/4" do
    defp post(attrs) do
      struct!(
        %Post{
          public_id: "pst000000001",
          slug: "/hello",
          publish_at: ~U[2024-03-06 23:30:00.000000Z],
          content: [%{"type" => "paragraph", "text" => "Hello."}]
        },
        attrs
      )
    end

    test "a post: front matter with title, URL, date and tags, then title and content",
         %{routes: r, context: c} do
      markdown = render(r, post(title: ~S|Say "hi" \ *now*|, tags: "elixir, web"), c)

      assert markdown == """
             ---
             title: "Say \\"hi\\" \\\\ *now*"
             url: "https://example.com/hello/"
             date: 2024-03-06
             tags:
               - "elixir"
               - "web"
             ---

             # Say "hi" \\\\ \\*now\\*

             Hello.
             """
    end

    test "a short post is titled by its meta title, without tags", %{routes: r, context: c} do
      markdown = render(r, post(title: nil, meta_title: "Greetings", tags: nil), c)

      assert markdown =~
               ~s(---\ntitle: "Greetings"\nurl: "https://example.com/hello/"\ndate: 2024-03-06\n---\n\n# Greetings\n\nHello.\n)
    end

    test "a short post without a meta title is titled by its first words", %{
      routes: r,
      context: c
    } do
      markdown = render(r, post(title: " ", meta_title: nil), c)

      assert markdown =~
               ~s(---\ntitle: "Hello."\nurl: "https://example.com/hello/"\ndate: 2024-03-06\n---\n\n# Hello.\n\nHello.\n)
    end

    test "front matter strings drop control characters and noncharacters, keep tabs and newlines",
         %{routes: r, context: c} do
      page = %Page{
        title: "Grüße\u007F\u0085\u009F\uFFFE\uFFFF\t🦉\u0001\r\n",
        slug: "/about",
        tags: "a\u0080b",
        content: []
      }

      markdown = render(r, page, c)

      assert markdown =~ ~S"""
             ---
             title: "Grüße\t🦉\n"
             url: "https://example.com/about/"
             tags:
               - "ab"
             ---
             """
    end

    test "a review names its book below the title", %{routes: r, context: c} do
      book = %Book{title: "Dune", author: "Frank Herbert", rating: 5}
      markdown = render(r, post(title: nil, book: book), c)

      assert markdown =~ "\n# Dune\n\n*Dune* · Frank Herbert · 5 of 5 stars\n\nHello.\n"
    end

    test "a page has no date", %{routes: r, context: c} do
      page = %Page{
        title: "About",
        slug: "/about",
        tags: "me",
        content: [%{"type" => "paragraph", "text" => "Me."}]
      }

      assert render(r, page, c) == """
             ---
             title: "About"
             url: "https://example.com/about/"
             tags:
               - "me"
             ---

             # About

             Me.
             """
    end

    test "an untitled page is titled by the site title", %{routes: r, context: c} do
      page = %Page{
        title: " ",
        slug: "/about",
        content: [%{"type" => "paragraph", "text" => "Me."}]
      }

      data = %SiteData{site: %Site{title: "My Site"}}

      assert render(r, page, c, data) ==
               ~s(---\ntitle: "My Site"\nurl: "https://example.com/about/"\n---\n\n# My Site\n\nMe.\n)
    end

    test "a project shows its description, content and links", %{routes: r, context: c} do
      project = %Project{
        title: "CMS",
        slug: "/cms",
        short_description: "Builds <b>sites</b>\nquickly.\n\nSecond.",
        content: [%{"type" => "paragraph", "text" => "Content."}],
        links: [
          %Project.Link{label: "Code", url: "https://github.com/x"},
          %Project.Link{label: "", url: "https://example.org/"},
          %Project.Link{label: "Evil", url: "javascript:alert(1)"}
        ]
      }

      assert render(r, project, c) == """
             ---
             title: "CMS"
             url: "https://example.com/projects/cms/"
             ---

             # CMS

             Builds **sites**\\
             quickly.

             Second.

             Content.

             ## Links

             - [Code](https://github.com/x)
             - [https://example.org/](https://example.org/)
             """
    end

    test "a project's description breaks lines between text only, not inside tags",
         %{routes: r, context: c} do
      project = %Project{
        title: "CMS",
        slug: "/cms",
        short_description: "Builds <a\nhref=\"/sites/\">sites</a>\nquickly.\r\n\r\nSecond.",
        content: []
      }

      assert render(r, project, c) =~
               "\n# CMS\n\nBuilds [sites](https://example.com/sites/)\\\nquickly.\n\nSecond.\n"
    end

    test "relative project links resolve against the project's URL, in its alternate and the projects page",
         %{routes: r, context: c} do
      project = %Project{
        title: "CMS",
        slug: "/cms",
        short_description: "Builds sites.",
        content: [],
        links: [
          %Project.Link{label: "Docs", url: "/docs/"},
          %Project.Link{label: "", url: "guide/"}
        ]
      }

      links =
        "- [Docs](https://example.com/docs/)\n" <>
          "- [https://example.com/projects/cms/guide/](https://example.com/projects/cms/guide/)\n"

      assert render(r, project, c) =~ "\n## Links\n\n" <> links

      page = %Page{title: "Work", slug: "/work", page_type: "projects", content: []}
      data = %SiteData{site: %Site{}, projects: [project]}

      assert render(r, page, c, data) =~ "\nBuilds sites.\n\n" <> links
    end

    test "the home page: the homepage content, then all posts with their date and excerpt",
         %{routes: r, context: c} do
      posts =
        for n <- 1..30 do
          post(
            public_id: "pst0000000#{n}",
            slug: "/post-#{n}",
            title: "Post #{n}",
            publish_at: DateTime.add(~U[2024-03-06 10:00:00.000000Z], -n, :day),
            content: [%{"type" => "paragraph", "text" => "Text of *#{n}*."}]
          )
        end

      short_post =
        post(
          slug: nil,
          title: nil,
          meta_title: "On notes",
          content: [%{"type" => "paragraph", "text" => "A note."}]
        )

      data = %SiteData{
        site: %Site{title: "My Site"},
        homepage: %Page{slug: "/", content: [%{"type" => "paragraph", "text" => "Welcome."}]},
        posts: [short_post | posts]
      }

      markdown = render(r, :home, c, data)

      assert String.starts_with?(markdown, """
             ---
             title: "My Site"
             url: "https://example.com/"
             ---

             # My Site

             Welcome.

             ## Posts

             ### [On notes](https://example.com/posts/pst000000001/)

             2024-03-06

             A note.

             ### [Post 1](https://example.com/post-1/)

             2024-03-05

             Text of \\*1\\*.

             ### [Post 2](https://example.com/post-2/)
             """)

      assert String.ends_with?(markdown, """
             ### [Post 30](https://example.com/post-30/)

             2024-02-05

             Text of \\*30\\*.
             """)
    end

    test "the home page without homepage and posts has only its title", %{routes: r, context: c} do
      data = %SiteData{site: %Site{title: "My Site"}, homepage: nil, posts: []}

      assert render(r, :home, c, data) ==
               ~s(---\ntitle: "My Site"\nurl: "https://example.com/"\n---\n\n# My Site\n)
    end

    test "a books page shows the bookshelf by year after its content", %{routes: r, context: c} do
      page = %Page{
        title: "Books",
        slug: "/books",
        page_type: "books",
        content: [%{"type" => "paragraph", "text" => "What I read."}]
      }

      review = post(slug: "/dune")

      books = [
        %Book{title: "Old", author: "O. Author", read_at: ~D[2023-07-09], post: nil},
        %Book{title: "Someday", author: "S", read_at: nil, post: nil},
        %Book{
          title: "Dune",
          author: "Frank Herbert",
          rating: 4,
          read_at: ~D[2025-02-01],
          post: review
        },
        %Book{title: "Emma [1]", author: "Jane Austen", read_at: ~D[2025-01-10], post: nil}
      ]

      data = %SiteData{site: %Site{}, posts: [review], books: books}

      assert render(r, page, c, data) == """
             ---
             title: "Books"
             url: "https://example.com/books/"
             ---

             # Books

             What I read.

             ## 2025

             - [*Dune*](https://example.com/dune/) · Frank Herbert · 4 of 5 stars · 2025-02-01
             - *Emma \\[1\\]* · Jane Austen · 2025-01-10

             ## 2023

             - *Old* · O. Author · 2023-07-09
             """
    end

    test "a projects page shows the projects with their description and links",
         %{routes: r, context: c} do
      page = %Page{title: "Work", slug: "/work", page_type: "projects", content: []}

      projects = [
        %Project{
          title: "Done",
          slug: "/done",
          status: "completed",
          started_at: ~D[2024-01-01],
          ended_at: ~D[2024-06-30],
          short_description: "Line one\nline two\n\nSecond <b>para</b>",
          links: [
            %Project.Link{label: "Code", url: "https://github.com/x"},
            %Project.Link{label: "Evil", url: "javascript:alert(1)"}
          ]
        },
        %Project{
          title: "Ongoing",
          slug: "/ongoing",
          status: "ongoing",
          started_at: ~D[2020-01-01]
        }
      ]

      data = %SiteData{site: %Site{}, projects: projects}

      assert render(r, page, c, data) == """
             ---
             title: "Work"
             url: "https://example.com/work/"
             ---

             # Work

             ## [Ongoing](https://example.com/projects/ongoing/)

             ## [Done](https://example.com/projects/done/)

             Line one\\
             line two

             Second **para**

             - [Code](https://github.com/x)
             """
    end

    test "other pages show no list", %{routes: r, context: c} do
      page = %Page{title: "About", slug: "/about", page_type: "default", content: []}
      data = %SiteData{site: %Site{}, books: [%Book{title: "Dune", read_at: ~D[2025-02-01]}]}

      refute render(r, page, c, data) =~ "Dune"
    end

    defp render(routes, target, context, data \\ %SiteData{site: %Site{}}) do
      data
      |> MarkdownAlternate.render(routes, target, context)
      |> IO.iodata_to_binary()
    end
  end
end
