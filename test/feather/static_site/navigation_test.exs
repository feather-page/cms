defmodule Feather.StaticSite.NavigationTest do
  use Feather.DataCase

  alias Feather.StaticSite.{Export, RecordingSink, Routes, SiteData}

  @day ~U[2025-01-01 10:00:00.000000Z]

  setup do
    scope = site_scope_fixture(%{title: "Site", emoji: "🦉"})

    oldest = post_fixture(scope, %{title: "Oldest", slug: "/oldest", publish_at: @day})

    untitled =
      post_fixture(scope, %{
        title: nil,
        slug: nil,
        emoji: "💬",
        tags: "short",
        content: [paragraph("Notes from a long walk along rivers, <b>at</b> dawn.")],
        publish_at: DateTime.add(@day, 1, :day)
      })

    newest =
      post_fixture(scope, %{
        title: "Newest",
        slug: "/newest",
        emoji: "🧪",
        tags: "elixir, web",
        publish_at: DateTime.add(@day, 2, :day)
      })

    post_fixture(scope, %{title: "Draft", slug: "/draft", draft: true})

    post_fixture(scope, %{
      title: "Scheduled",
      slug: "/scheduled",
      publish_at: DateTime.add(DateTime.utc_now(), 3600)
    })

    page_fixture(scope, %{title: "About", slug: "/about", emoji: "👋", add_to_navigation: true})

    page_fixture(scope, %{
      title: "Work",
      slug: "/work",
      emoji: "🛠",
      page_type: "projects",
      add_to_navigation: true
    })

    project_fixture(scope, %{title: "Thing", slug: "/thing", emoji: "🔧"})

    sink = RecordingSink.new(start_supervised!(RecordingSink))
    :ok = Export.run(scope.site, Routes.new(scope.site), sink)

    %{scope: scope, sink: sink, oldest: oldest, untitled: untitled, newest: newest}
  end

  defp doc(sink, path), do: sink |> RecordingSink.get(path) |> Floki.parse_document!()

  defp hrefs(doc, selector), do: Floki.attribute(doc, selector, "href")

  defp untitled_path(post), do: "/posts/#{String.downcase(post.public_id)}/"

  test "neighbours follow the home list, newest first, published and due posts only", c do
    data = SiteData.load(c.scope.site)

    assert {nil, %{id: untitled_id}} = SiteData.neighbours(data, c.newest)
    assert untitled_id == c.untitled.id
    assert {%{title: "Newest"}, %{title: "Oldest"}} = SiteData.neighbours(data, c.untitled)
    assert {%{id: ^untitled_id}, nil} = SiteData.neighbours(data, c.oldest)
  end

  test "a post links to its newer and older neighbours and to all posts", c do
    middle = doc(c.sink, "posts/#{String.downcase(c.untitled.public_id)}/index.html")

    assert hrefs(middle, ".post-nav-newer a") == ["/newest/"]
    assert hrefs(middle, ".post-nav-older a") == ["/oldest/"]
    assert hrefs(middle, ".post-nav-all a") == ["/#posts"]
    assert middle |> Floki.find(".post-nav-newer a") |> Floki.text() =~ "🧪"

    newest = doc(c.sink, "newest/index.html")
    assert hrefs(newest, ".post-nav-newer a") == []
    assert hrefs(newest, ".post-nav-older a") == [untitled_path(c.untitled)]

    assert newest |> Floki.find(".post-nav-older a") |> Floki.text() ==
             "💬Notes from a long walk along rivers…"

    oldest = doc(c.sink, "oldest/index.html")
    assert hrefs(oldest, ".post-nav-older a") == []
  end

  test "a single post has no neighbours, only the link to all posts" do
    scope = site_scope_fixture()
    post_fixture(scope, %{title: "Only", slug: "/only", publish_at: @day})
    sink = RecordingSink.new(start_supervised!(RecordingSink, id: :single))
    :ok = Export.run(scope.site, Routes.new(scope.site), sink)

    html = doc(sink, "only/index.html")
    assert Floki.find(html, ".post-nav-newer, .post-nav-older") == []
    assert hrefs(html, ".post-nav-all a") == ["/#posts"]
  end

  test "an untitled post without text is labelled by its date" do
    scope = site_scope_fixture()
    post_fixture(scope, %{title: nil, slug: nil, content: [], publish_at: @day})

    post_fixture(scope, %{title: "Later", slug: "/later", publish_at: DateTime.add(@day, 1, :day)})

    sink = RecordingSink.new(start_supervised!(RecordingSink, id: :textless))
    :ok = Export.run(scope.site, Routes.new(scope.site), sink)

    assert sink |> doc("later/index.html") |> Floki.find(".post-nav-older a") |> Floki.text() ==
             "January 1, 2025"
  end

  test "every page carries the site navigation", c do
    for path <- ["newest/index.html", "about/index.html", "projects/thing/index.html", "404.html"] do
      assert hrefs(doc(c.sink, path), "footer nav a") == ["/about/", "/work/"], path
    end

    about = doc(c.sink, "about/index.html")
    assert Floki.attribute(about, ~s(footer nav a[href="/about/"]), "aria-current") == ["page"]
  end

  test "the project breadcrumb leads through the projects page", c do
    project = doc(c.sink, "projects/thing/index.html")

    assert hrefs(project, ".breadcrumb a") == ["/", "/work/"]
    assert project |> Floki.find(~s(.breadcrumb a[href="/work/"])) |> Floki.text() =~ "🛠"
  end

  test "emoji sit inside the links of the breadcrumb and the home masthead", c do
    about = doc(c.sink, "about/index.html")

    assert [{"a", _, _} = site_link] = Floki.find(about, ".breadcrumb a")
    assert Floki.text(site_link) =~ "🦉"
    assert about |> Floki.find(~s(.breadcrumb [aria-current="page"])) |> Floki.text() == "About"

    home = doc(c.sink, "index.html")
    assert home |> Floki.find(~s(.masthead-links a[href="/about/"])) |> Floki.text() =~ "👋"
  end

  test "an untitled post's date links to the post", c do
    home = doc(c.sink, "index.html")

    assert untitled_path(c.untitled) in hrefs(home, ".post-date a")
    assert Floki.attribute(home, ".post-date a time", "datetime") == ["2025-01-02"]
  end

  test "tags are plain metadata, not badges", c do
    post = doc(c.sink, "newest/index.html")

    assert post |> Floki.find(".tags .tag") |> Enum.map(&Floki.text/1) == ["elixir", "web"]
    assert Floki.find(post, ".badge") == []
  end
end
