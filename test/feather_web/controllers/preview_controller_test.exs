defmodule FeatherWeb.PreviewControllerTest do
  use FeatherWeb.ConnCase

  alias Feather.StaticSite.Themes.{FeatherPage, SimpleSidebar}

  setup [:register_and_log_in_user, :create_site_for_user]

  setup %{site: site} do
    %{root: "/preview/#{site.public_id}"}
  end

  test "renders the home page with preview links", %{
    conn: conn,
    scope: scope,
    root: root,
    user: user
  } do
    post = post_fixture(scope, %{title: "Hello", slug: "/hello"})
    page_fixture(scope, %{title: "About", slug: "/about", add_to_navigation: true})

    conn = get(conn, root <> "/")
    html = html_response(conn, 200)

    assert get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]
    assert html =~ ~s(<h3 class="post-title"><a href="#{root}/hello/">#{post.title}</a></h3>)
    assert html =~ ~s(href="#{root}/about/")

    assert html =~ ~s(<h1 class="site-title">My Site</h1>)
    assert html =~ ~s(<link rel="stylesheet" href="#{root}/style.css?v=)

    refute html =~ "phx-r"

    assert html_response(get(fresh(user), root), 200) =~ ~s(<h2 id="posts">Posts</h2>)
  end

  test "renders posts (also drafts), pages and projects", %{conn: conn, scope: scope, root: root} do
    post_fixture(scope, %{title: "Secret draft", slug: "/draft", draft: true})
    page_fixture(scope, %{title: "About me", slug: "/about"})
    project_fixture(scope, %{title: "Big project", slug: "/big"})
    untitled = post_fixture(scope, %{title: nil, slug: nil})

    assert html_response(get(conn, root <> "/draft/"), 200) =~ "<h1>Secret draft</h1>"
    assert html_response(get(conn, root <> "/about"), 200) =~ "<h1>About me</h1>"
    assert html_response(get(conn, root <> "/projects/big/"), 200) =~ "<h1>Big project</h1>"

    path = "#{root}/posts/#{String.downcase(untitled.public_id)}/index.html"
    assert html_response(get(conn, path), 200) =~ "Hello from a post."
  end

  test "shows unpublished changes", %{conn: conn, scope: scope, root: root} do
    post_fixture(scope, %{title: "Published", slug: "/hello"})
    |> Ecto.Changeset.change(title: "Unpublished change")
    |> Feather.Repo.update!()

    assert html_response(get(conn, root <> "/"), 200) =~ "Unpublished change"
    assert html_response(get(conn, root <> "/hello/"), 200) =~ "<h1>Unpublished change</h1>"
  end

  test "serves stored variants and those an image's roles need, generating missing ones",
       %{conn: conn, scope: scope, root: root, user: user} do
    image = image_fixture(scope, width: 1000, height: 700)
    post_fixture(scope, %{header_image_id: image.id})
    refute File.exists?(Feather.Media.variant_path(image, "640.webp"))

    conn = get(conn, "#{root}/images/#{image.public_id}/640.webp")
    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["image/webp"]
    assert conn.resp_body == File.read!(Feather.Media.variant_path(image, "640.webp"))

    conn = get(fresh(user), "#{root}/images/#{image.public_id}/1200.jpg")
    assert get_resp_header(conn, "content-type") == ["image/jpeg"]

    assert get(fresh(user), "#{root}/images/#{image.public_id}/480.webp").status == 200

    for file <- ~w(128.webp original.png mobile_x1.webp) do
      assert get(fresh(user), "#{root}/images/#{image.public_id}/#{file}").status == 404, file
    end
  end

  test "renders diagrams and serves their SVG files without scripts", %{
    conn: conn,
    scope: scope,
    root: root,
    user: user
  } do
    Feather.FakeD2.install()

    post_fixture(scope, %{
      slug: "/flow",
      publish_at: DateTime.add(DateTime.utc_now(), 1, :day),
      content: [%{"type" => "diagram", "code" => "a -> b", "caption" => "Flow"}]
    })

    html = html_response(get(conn, root <> "/flow/"), 200)
    [_, src] = Regex.run(~r{<img loading="lazy" src="([^"]+)" alt="Flow">}, html)
    assert String.starts_with?(src, root <> "/diagrams/")

    conn = get(fresh(user), src)
    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["image/svg+xml"]
    assert [csp] = get_resp_header(conn, "content-security-policy")
    assert csp =~ "default-src 'none'"
    assert csp =~ "sandbox"
    assert conn.resp_body =~ "a -> b"

    missing = root <> "/diagrams/" <> String.duplicate("0", 64) <> ".svg"
    assert get(fresh(user), missing).status == 404
  end

  test "highlights code blocks, also of a scheduled post", %{
    conn: conn,
    scope: scope,
    root: root
  } do
    Feather.FakeChroma.install()

    post_fixture(scope, %{
      slug: "/code",
      publish_at: DateTime.add(DateTime.utc_now(), 1, :day),
      content: [%{"type" => "code", "code" => "puts 1", "language" => "ruby"}]
    })

    assert html_response(get(conn, root <> "/code/"), 200) =~
             ~s(<code class="language-ruby">#{Feather.FakeChroma.html("puts 1")}</code>)
  end

  test "renders diagrams only for what shows content", %{
    conn: conn,
    scope: scope,
    root: root,
    user: user
  } do
    Feather.FakeD2.install()
    post_fixture(scope, %{content: [%{"type" => "diagram", "code" => "a -> b"}]})

    assert get(conn, root <> "/missing/").status == 404
    assert get(fresh(user), root <> "/robots.txt").status == 200
    assert get(fresh(user), root <> "/sitemap.xml").status == 200
    refute_received {:d2_rendered, _source}

    assert get(fresh(user), root <> "/feed.xml").status == 200
    assert_received {:d2_rendered, _source}
  end

  test "serves the theme fonts", %{conn: conn, root: root} do
    conn = get(conn, root <> "/fonts/nunito-latin-800.woff2")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["font/woff2"]

    assert conn.resp_body ==
             File.read!(FeatherPage.font_path("nunito-latin-800.woff2"))
  end

  test "serves the stylesheet the pages link as text/css", %{conn: conn, root: root, user: user} do
    [href] =
      get(conn, root <> "/")
      |> html_response(200)
      |> LazyHTML.from_document()
      |> LazyHTML.query(~s(link[rel="stylesheet"]))
      |> LazyHTML.attribute("href")

    assert href =~ ~r"\A#{root}/style\.css\?v=[0-9a-f]{12}\z"

    conn = get(fresh(user), href)

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/css; charset=utf-8"]
    assert conn.resp_body =~ ~s[url("#{root}/fonts/nunito-latin-800.woff2?v=]
    assert String.ends_with?(conn.resp_body, FeatherPage.css())
  end

  test "serves the favicon the pages link, drawn from the site's emoji", %{
    conn: conn,
    scope: scope,
    root: root,
    user: user
  } do
    {:ok, _site} = Feather.Sites.update_site(scope, scope.site, %{emoji: "🦊"})

    [href] =
      get(conn, root <> "/")
      |> html_response(200)
      |> LazyHTML.from_document()
      |> LazyHTML.query(~s(link[rel="icon"]))
      |> LazyHTML.attribute("href")

    assert href =~ ~r"\A#{root}/images/[0-9a-f]{64}\.png\z"

    conn = get(fresh(user), href)

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["image/png"]
    assert <<137, "PNG", _rest::binary>> = conn.resp_body

    assert get(fresh(user), root <> "/images/#{String.duplicate("0", 64)}.png").status == 404
  end

  test "serves only the fonts of the site's theme", %{conn: conn, scope: scope, root: root} do
    scope.site |> Ecto.Changeset.change(theme: "simple_sidebar") |> Feather.Repo.update!()

    conn = get(conn, root <> "/fonts/schibsted-grotesk-latin-wght.woff2")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["font/woff2"]

    assert conn.resp_body ==
             File.read!(SimpleSidebar.font_path("schibsted-grotesk-latin-wght.woff2"))

    assert html_response(get(recycle(conn), root <> "/fonts/nunito-latin-800.woff2"), 404) =~
             "Page not found"
  end

  test "serves the feed with URLs on the site's domain", %{conn: conn, scope: scope, root: root} do
    post_fixture(scope, %{title: "Hello", slug: "/hello"})

    conn = get(conn, root <> "/feed.xml")
    assert response(conn, 200) =~ "<link>https://#{scope.site.domain}/hello/</link>"
    assert response_content_type(conn, :xml) =~ "application/rss+xml"
  end

  test "unknown paths inside a site render its 404 page", %{conn: conn, root: root, user: user} do
    html = html_response(get(conn, root <> "/nothing-here"), 404)
    assert html =~ "<h1>Page not found</h1>"
    assert html =~ ~s(<a class="not-found-home" href="#{root}/">)

    assert html_response(get(fresh(user), root <> "/images/unknown/640.webp"), 404) =~
             "<h1>Page not found</h1>"

    assert response(get(fresh(user), "/preview/unknown00000/"), 404) == "Not Found"
  end

  test "answers an old path with a redirect to the target inside the preview", %{
    conn: conn,
    scope: scope,
    root: root,
    user: user
  } do
    post = post_fixture(scope, %{slug: "/rule-of-72"})
    redirect_fixture(scope, old_path: "/posts/rule-of-72", target: "/rule-of-72/")
    redirect_fixture(scope, old_path: "/atom.xml", target: "/feed.xml", kind: "temporary")
    {:ok, _} = Feather.Content.update_post(scope, post, %{slug: "/unpublished-slug"})

    assert redirected_to(get(conn, root <> "/posts/rule-of-72"), 302) ==
             root <> "/unpublished-slug/"

    assert redirected_to(get(fresh(user), root <> "/posts/rule-of-72/"), 302) ==
             root <> "/unpublished-slug/"

    assert redirected_to(get(fresh(user), root <> "/atom.xml"), 302) == root <> "/feed.xml"
  end

  test "renders the 404 page for the old path of an inactive redirect", %{
    conn: conn,
    scope: scope,
    root: root
  } do
    page = page_fixture(scope, %{slug: "/target"})
    redirect_fixture(scope, old_path: "/old", target: "/target")
    {:ok, _} = Feather.Content.unpublish(scope, page)

    assert get(conn, root <> "/old").status == 404
  end

  test "sites the user may not access are not found", %{conn: conn, user: user} do
    other = site_fixture()
    assert response(get(conn, "/preview/#{other.public_id}/"), 404) == "Not Found"
    assert response(get(fresh(user), "/preview/#{other.public_id}/about"), 404) == "Not Found"
  end

  test "a site without a deployment target has a preview", %{conn: conn, scope: scope, root: root} do
    assert Feather.Publishing.get_target(scope) == nil
    assert html_response(get(conn, root <> "/"), 200) =~ ~s(<h2 id="posts">Posts</h2>)
  end

  test "super admins may preview every site", %{conn: conn} do
    other = site_fixture()
    admin = super_admin_fixture()

    conn = conn |> recycle() |> log_in_user(admin)

    assert html_response(get(conn, "/preview/#{other.public_id}/"), 200) =~
             ~s(<h2 id="posts">Posts</h2>)
  end

  test "requires login", %{root: root} do
    conn = get(Phoenix.ConnTest.build_conn(), root <> "/")
    assert redirected_to(conn) == ~p"/users/log-in"
  end

  defp fresh(user), do: log_in_user(build_conn(), user)
end
