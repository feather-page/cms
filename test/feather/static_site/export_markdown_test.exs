defmodule Feather.StaticSite.ExportMarkdownTest do
  use Feather.DataCase

  alias Feather.{Books, Content}
  alias Feather.StaticSite.{Export, RecordingSink, Routes}

  @publish_at ~U[2024-03-06 10:00:00.000000Z]

  defp export(theme) do
    scope = site_scope_fixture(%{theme: theme, bio: "I write about the web."})
    image = image_fixture(scope, width: 800, height: 600)

    post_fixture(scope, %{
      title: "Hello",
      slug: "/hello",
      tags: "elixir, web",
      publish_at: @publish_at,
      content: [paragraph(~S|See <a href="/about/">about</a>.|), image_block(image, "A view")]
    })

    review_fixture(scope)

    page_fixture(scope, %{
      title: "About",
      slug: "/about",
      description: "Who I am.",
      content: [paragraph("Me.")]
    })

    page_fixture(scope, %{title: "Books", slug: "/books", page_type: "books", content: []})
    page_fixture(scope, %{title: "Work", slug: "/work", page_type: "projects", content: []})
    project_fixture(scope, %{title: "CMS", slug: "/cms", content: [paragraph("Code.")]})

    homepage = Content.get_homepage(scope)
    {:ok, homepage} = Content.update_page(scope, homepage, %{content: [paragraph("Welcome.")]})
    {:ok, _} = Content.publish(scope, homepage)

    sink = RecordingSink.new(start_supervised!(RecordingSink, id: make_ref()))
    routes = Routes.new(scope.site, canonical_url: "https://example.com/")
    :ok = Export.run(Repo.reload!(scope.site), routes, sink)

    %{sink: sink, image: image}
  end

  defp review_fixture(scope) do
    book = book_fixture(scope, %{title: "Dune", author: "Frank Herbert", read_at: ~D[2024-02-01]})

    {:ok, %{post: review}} =
      Books.create_review(scope, book, %{
        title: "",
        meta_title: "Reading Dune",
        slug: "/dune",
        content: [paragraph("Loved it.")],
        publish_at: DateTime.add(@publish_at, -1, :day)
      })

    {:ok, review} = Content.publish(scope, review)
    review
  end

  defp doc(sink, path), do: sink |> RecordingSink.get(path) |> LazyHTML.from_document()

  defp meta(doc, selector),
    do: doc |> LazyHTML.query("meta" <> selector) |> LazyHTML.attribute("content")

  defp alternate_links(sink, path) do
    sink
    |> doc(path)
    |> LazyHTML.query(~s(link[rel="alternate"][type="text/markdown"]))
    |> LazyHTML.attribute("href")
  end

  test "writes index.md next to the home page and the page of every post, page and project" do
    %{sink: sink} = export("feather")
    paths = RecordingSink.paths(sink)

    for path <-
          ~w(index.md hello/index.md dune/index.md about/index.md books/index.md work/index.md projects/cms/index.md) do
      assert path in paths, "#{path} missing from #{inspect(paths)}"
      assert RecordingSink.get(sink, path) =~ ~r/\A---\ntitle: /, path
    end

    assert Enum.count(paths, &String.ends_with?(&1, ".md")) == 7
  end

  test "the home page's Markdown alternate holds the homepage content and the posts" do
    %{sink: sink} = export("feather")

    assert RecordingSink.get(sink, "index.md") == """
           ---
           title: "My Site"
           url: "https://example.com/"
           ---

           # My Site

           Welcome.

           ## Posts

           ### [Hello](https://example.com/hello/)

           2024-03-06

           See about.

           ### [Reading Dune](https://example.com/dune/)

           2024-03-05

           Loved it.
           """
  end

  test "the Markdown alternates of books and projects pages include their list" do
    %{sink: sink} = export("feather")

    assert RecordingSink.get(sink, "books/index.md") =~
             "\n## 2024\n\n- [*Dune*](https://example.com/dune/) · Frank Herbert · 2024-02-01\n"

    assert RecordingSink.get(sink, "work/index.md") =~
             "\n## [CMS](https://example.com/projects/cms/)\n\nSomething I built.\n"
  end

  test "llms.txt links the Markdown alternates of all pages, posts and projects with their descriptions" do
    %{sink: sink} = export("feather")

    assert RecordingSink.get(sink, "llms.txt") == """
           # My Site

           > I write about the web.

           ## Pages

           - [Home](https://example.com/index.md): Welcome.
           - [About](https://example.com/about/index.md): Who I am.
           - [Books](https://example.com/books/index.md)
           - [Work](https://example.com/work/index.md)

           ## Posts

           - [Hello](https://example.com/hello/index.md): See about.
           - [Reading Dune](https://example.com/dune/index.md): Loved it.

           ## Projects

           - [CMS](https://example.com/projects/cms/index.md): Something I built.
           """
  end

  test "a short post's alternate and llms.txt take the title its page has, llms.txt the page's description" do
    %{sink: sink} = export("feather")
    llms_txt = RecordingSink.get(sink, "llms.txt")

    assert meta(doc(sink, "dune/index.html"), ~s([property="og:title"])) == ["Reading Dune"]
    assert RecordingSink.get(sink, "dune/index.md") =~ ~s(---\ntitle: "Reading Dune"\n)
    assert RecordingSink.get(sink, "dune/index.md") =~ "\n# Reading Dune\n"
    assert llms_txt =~ "\n- [Reading Dune](https://example.com/dune/index.md): Loved it.\n"

    assert meta(doc(sink, "about/index.html"), ~s([name="description"])) == ["Who I am."]
    assert llms_txt =~ "\n- [About](https://example.com/about/index.md): Who I am.\n"
  end

  test "a post's Markdown alternate has its front matter, title and content with canonical URLs" do
    %{sink: sink, image: image} = export("feather")

    assert RecordingSink.get(sink, "hello/index.md") == """
           ---
           title: "Hello"
           url: "https://example.com/hello/"
           date: 2024-03-06
           tags:
             - "elixir"
             - "web"
           ---

           # Hello

           See [about](https://example.com/about/).

           ![A view](https://example.com/images/#{image.public_id}/960.webp)
           """
  end

  test "every page with a Markdown alternate links it in its head, in both themes" do
    for theme <- ["feather", "simple_sidebar"] do
      %{sink: sink} = export(theme)

      for {page, alternate} <- [
            {"index.html", "/index.md"},
            {"hello/index.html", "/hello/index.md"},
            {"about/index.html", "/about/index.md"},
            {"books/index.html", "/books/index.md"},
            {"projects/cms/index.html", "/projects/cms/index.md"}
          ] do
        assert alternate_links(sink, page) == [alternate], "#{theme} #{page}"
      end

      assert alternate_links(sink, "404.html") == [], theme
    end
  end
end
