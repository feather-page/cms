defmodule FeatherWeb.SiteShellTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  setup [:register_and_log_in_user, :create_site_for_user]

  for {path, active} <- [
        {"/posts", "Posts"},
        {"/pages", "Pages"},
        {"/books", "Books"},
        {"/projects", "Projects"},
        {"/settings", "Settings"},
        {"/redirects", "Redirects"},
        {"/users", "Users"},
        {"/deployments", "Deployments"}
      ] do
    test "#{path} shows the site navigation and the preview link", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, "/sites/#{site.public_id}#{unquote(path)}")

      assert has_element?(lv, "#site-switcher-sidebar-title", site.title)
      assert has_element?(lv, "nav[aria-label=Main] a[aria-current=page]", unquote(active))
      assert has_element?(lv, ~s(#site-preview-link-sidebar[href="/preview/#{site.public_id}"]))
    end
  end

  test "the notices' live region is there before the first notice", %{conn: conn, site: site} do
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

    assert has_element?(lv, ~s(#site-notices[aria-live="polite"]))
    refute has_element?(lv, "#site-notices .alert")
  end

  test "the section navigation marks the current section", %{conn: conn, site: site} do
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/books")

    assert has_element?(lv, ~s(nav[aria-label=Main] a[aria-current="page"]), "Books")
    refute has_element?(lv, ~s(nav[aria-label=Main] a[aria-current="page"]), "Posts")

    for section <- ~w(posts pages books projects settings redirects users deployments) do
      assert has_element?(
               lv,
               ~s(nav[aria-label=Main] a[href="/sites/#{site.public_id}/#{section}"])
             )
    end
  end

  test "the site switcher lists the user's sites and all sites", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    other = site_fixture(scope, title: "Other blog")
    foreign = site_fixture(nil, title: "Someone else's blog")
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

    assert has_element?(lv, "#site-switcher-sidebar > summary", site.title)
    assert has_element?(lv, "details#site-switcher-sidebar:not([open])")

    assert has_element?(
             lv,
             ~s(#site-switcher-sidebar ul a[href="/sites/#{other.public_id}/posts"]),
             "Other blog"
           )

    assert has_element?(
             lv,
             ~s(#site-switcher-sidebar ul a[aria-current="page"][href="/sites/#{site.public_id}/posts"])
           )

    refute has_element?(
             lv,
             ~s(#site-switcher-sidebar ul a[href="/sites/#{foreign.public_id}/posts"])
           )

    assert has_element?(lv, ~s(#site-switcher-sidebar li.border-t a[href="/"]), "All sites")
  end

  test "Escape in the site switcher puts focus back on its toggle", %{conn: conn, site: site} do
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

    for selector <- [
          "#site-switcher-sidebar > summary",
          "#site-switcher-sidebar a[aria-current]",
          ~s(#site-switcher-sidebar a[href="/"])
        ] do
      html = lv |> element(selector) |> render()
      assert html =~ ~s(phx-key="Escape")

      assert html =~
               ~s(&quot;focus_first&quot;,{&quot;to&quot;:&quot;#site-switcher-sidebar&quot;})
    end
  end

  test "the top bar and the sidebar foot have a user menu", %{
    conn: conn,
    site: site,
    user: user
  } do
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts")

    for menu <- ~w(#user-menu-bar #user-menu-sidebar) do
      assert has_element?(lv, ~s(#{menu} > summary[aria-label="Account"]))
      assert has_element?(lv, ~s(#{menu} ul a[href="/users/settings"]), "Account settings")
      assert has_element?(lv, ~s(#{menu} ul a[href="/users/log-out"]), "Log out")
    end

    assert has_element?(lv, "details#user-menu-sidebar.dropdown-top > summary", user.email)
    assert has_element?(lv, "#user-menu-bar #current-user-email", user.email)
  end

  test "a detail page shows breadcrumbs and its status in place of the site switcher", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    post = post_fixture(scope, title: "Winter notes")
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/posts/#{post.public_id}/edit")

    assert has_element?(
             lv,
             ~s(header nav[aria-label=Breadcrumb] a[href="/sites/#{site.public_id}/posts"]),
             "Posts"
           )

    assert has_element?(lv, ~s(header h1[aria-current="page"]), "Winter notes")
    assert has_element?(lv, "header #status-badge")
    refute has_element?(lv, "header #site-switcher-bar")
  end

  test "the deployments page renders in the shell", %{conn: conn, site: site, scope: scope} do
    deployment_target_fixture(scope)

    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/deployments")

    assert has_element?(lv, "nav[aria-label=Main] a[aria-current=page]", "Deployments")
  end

  test "a LiveView survives the manual deploy message", %{conn: conn, site: site, scope: scope} do
    page_fixture(scope, title: "About")
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/pages")

    send(lv.pid, {:deploy_requested, deployment_target_fixture(scope)})
    assert render(lv) =~ "About"
  end
end
