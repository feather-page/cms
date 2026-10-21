defmodule Feather.StaticSite.LlmsTxtTest do
  use ExUnit.Case, async: true

  alias Feather.Content.{Page, Post, Project}
  alias Feather.Sites.Site
  alias Feather.StaticSite.{LlmsTxt, Routes, SiteData}

  @site %Site{title: "My [Site]", bio: "I write\nabout *code*."}

  defp render(data) do
    routes =
      Routes.new(data.site, site_root: "/preview/x/", canonical_url: "https://example.com/")

    data |> LlmsTxt.render(routes) |> IO.iodata_to_binary()
  end

  defp paragraph(text), do: [%{"type" => "paragraph", "text" => text}]

  test "links the canonical Markdown alternates of all pages, posts and projects, titled and described as their pages are" do
    data = %SiteData{
      site: @site,
      pages: [
        %Page{title: "Home", slug: "/", content: paragraph("Welcome <b>home</b>.")},
        %Page{title: "Books", slug: "/books", content: []},
        %Page{
          title: "About",
          slug: "/about",
          description: "  Who I am\nand what I do.",
          content: paragraph("Me.")
        }
      ],
      posts: [
        %Post{
          title: "Hello",
          slug: "/hello",
          publish_at: ~U[2024-03-06 10:00:00Z],
          content: paragraph(String.duplicate("word ", 40))
        },
        %Post{
          title: nil,
          meta_title: "Solar dashboard",
          slug: "/solar-dashboard",
          publish_at: ~U[2024-03-05 12:00:00Z],
          description: "An e-ink dashboard for the balcony plant.",
          content: paragraph("Built a dashboard.")
        },
        %Post{
          title: nil,
          slug: nil,
          public_id: "ABC123xyz789",
          publish_at: ~U[2024-03-05 10:00:00Z],
          content: paragraph("A short note.")
        }
      ],
      projects: [
        %Project{
          title: "CMS",
          slug: "/cms",
          short_description: "Builds <i>sites</i>.",
          content: paragraph("Long text.")
        },
        %Project{
          title: "Tool",
          slug: "/tool",
          short_description: nil,
          content: paragraph("Helps.")
        }
      ]
    }

    assert render(data) == """
           # My \\[Site\\]

           > I write about \\*code\\*.

           ## Pages

           - [Home](https://example.com/index.md): Welcome home.
           - [Books](https://example.com/books/index.md)
           - [About](https://example.com/about/index.md): Who I am and what I do.

           ## Posts

           - [Hello](https://example.com/hello/index.md): #{String.trim(String.duplicate("word ", 31))}…
           - [Solar dashboard](https://example.com/solar-dashboard/index.md): An e-ink dashboard for the balcony plant.
           - [A short note.](https://example.com/posts/abc123xyz789/index.md): A short note.

           ## Projects

           - [CMS](https://example.com/projects/cms/index.md): Builds sites.
           - [Tool](https://example.com/projects/tool/index.md): Helps.
           """
  end

  test "names an untitled page by the site title" do
    data = %SiteData{
      site: %Site{title: "My Site", bio: nil},
      pages: [
        %Page{title: "Home", slug: "/", content: []},
        %Page{title: nil, slug: "/about", content: paragraph("Me.")}
      ]
    }

    assert render(data) =~ """
           - [Home](https://example.com/index.md)
           - [My Site](https://example.com/about/index.md): Me.
           """
  end

  test "leaves out the summary without a bio and sections without entries" do
    data = %SiteData{
      site: %Site{title: "My Site", bio: nil},
      pages: [%Page{title: "Home", slug: "/", content: []}]
    }

    assert render(data) == """
           # My Site

           ## Pages

           - [Home](https://example.com/index.md)
           """
  end
end
