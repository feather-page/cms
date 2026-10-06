defmodule FeatherWeb.PreviewControllerTest do
  use FeatherWeb.ConnCase

  alias Feather.Publishing

  setup [:register_and_log_in_user, :create_site_for_user]

  setup %{scope: scope} do
    target = Publishing.get_staging_target(scope)
    %{target: target, root: "/preview/#{target.public_id}"}
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
    assert html =~ ~s(<a class="post-title" href="#{root}/hello/">#{post.title}</a>)
    assert html =~ ~s(href="#{root}/about/")
    assert html =~ ~s(<a href="#{root}/">My Site</a>)
    refute html =~ "phx-r"

    assert html_response(get(fresh(user), root), 200) =~ "Blogposts"
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

  test "serves image variants with their content type", %{
    conn: conn,
    scope: scope,
    root: root,
    user: user
  } do
    image = image_fixture(scope)

    conn = get(conn, "#{root}/images/#{image.public_id}/mobile_x1.webp")
    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["image/webp"]
    assert conn.resp_body == File.read!(Feather.Media.variant_path(image, "mobile_x1.webp"))

    conn = get(fresh(user), "#{root}/images/#{image.public_id}/desktop_x1.jpg")
    assert get_resp_header(conn, "content-type") == ["image/jpeg"]

    assert get(fresh(user), "#{root}/images/#{image.public_id}/original.png").status ==
             404
  end

  test "serves the feed with canonical URLs", %{conn: conn, scope: scope, root: root, target: t} do
    post_fixture(scope, %{title: "Hello", slug: "/hello"})

    conn = get(conn, root <> "/feed.xml")
    assert response(conn, 200) =~ "<link>https://#{t.public_hostname}/hello/</link>"
    assert response_content_type(conn, :xml) =~ "application/rss+xml"
  end

  test "unknown paths are not found", %{conn: conn, root: root, user: user} do
    assert response(get(conn, root <> "/nothing-here"), 404)
    assert response(get(fresh(user), "/preview/unknown00000/"), 404)
  end

  test "targets of other sites are not found", %{conn: conn} do
    other = Publishing.get_staging_target(site_scope_fixture())
    assert response(get(conn, "/preview/#{other.public_id}/"), 404)
  end

  test "super admins may preview every site", %{conn: conn} do
    other = Publishing.get_staging_target(site_scope_fixture())
    admin = super_admin_fixture()

    conn = conn |> recycle() |> log_in_user(admin)
    assert html_response(get(conn, "/preview/#{other.public_id}/"), 200) =~ "Blogposts"
  end

  test "requires login", %{root: root} do
    conn = get(Phoenix.ConnTest.build_conn(), root <> "/")
    assert redirected_to(conn) == ~p"/users/log-in"
  end

  # A new request of the logged-in user.
  defp fresh(user), do: log_in_user(build_conn(), user)
end
