defmodule FeatherWeb.SiteShellTest do
  # Every page under /sites/:site_id renders in the site shell.
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.Publishing

  setup [:register_and_log_in_user, :create_site_for_user]

  for {path, active} <- [
        {"/posts", "Posts"},
        {"/pages", "Pages"},
        {"/books", "Books"},
        {"/projects", "Projects"},
        {"/settings", "Settings"},
        {"/users", "Users"},
        {"/deployments", "Deployments"}
      ] do
    test "#{path} shows the site navigation and the preview link", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      target = Publishing.get_staging_target(scope)
      {:ok, lv, _html} = live(conn, "/sites/#{site.public_id}#{unquote(path)}")

      assert has_element?(lv, "#site-switcher-sidebar-title", site.title)
      assert has_element?(lv, "nav[aria-label=Main] a[aria-current=page]", unquote(active))
      assert has_element?(lv, ~s(#site-preview-link-sidebar[href="/preview/#{target.public_id}"]))
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

    for section <- ~w(posts pages books projects settings users deployments) do
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

  test "the deployment form renders in the shell", %{conn: conn, site: site, scope: scope} do
    target = Publishing.get_staging_target(scope)

    {:ok, lv, _html} =
      live(conn, ~p"/sites/#{site.public_id}/deployments/#{target.public_id}/edit")

    assert has_element?(lv, "nav[aria-label=Main] a[aria-current=page]", "Deployments")
  end

  test "a LiveView that publishes survives the manual deploy message", %{
    conn: conn,
    site: site,
    scope: scope
  } do
    page = page_fixture(scope, title: "About")
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/pages")

    # publish_site/1 sends {:deploy_requested, target} to the LiveView in tests
    lv |> element("#add-to-navigation-#{page.public_id}") |> render_click()

    assert has_element?(lv, "#navigation-item-#{page.public_id}")
    send(lv.pid, {:deploy_requested, Publishing.get_staging_target(scope)})
    assert render(lv) =~ "About"
  end
end
