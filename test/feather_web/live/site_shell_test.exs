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

      assert has_element?(lv, "#site-title", site.title)
      assert has_element?(lv, "#site-navigation a.active", unquote(active))
      assert has_element?(lv, ~s(#site-preview-link[href="/preview/#{target.public_id}"]))
    end
  end

  test "the section navigation marks the current section", %{conn: conn, site: site} do
    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/books")

    assert has_element?(lv, ~s(#site-navigation a.active[aria-current="page"]), "Books")
    refute has_element?(lv, ~s(#site-navigation a[aria-current="page"]), "Posts")

    for section <- ~w(posts pages books projects settings users deployments) do
      assert has_element?(lv, ~s(#site-navigation a[href="/sites/#{site.public_id}/#{section}"]))
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

    assert has_element?(lv, "#site-switcher-toggle", site.title)
    assert has_element?(lv, ~s(#site-switcher-toggle[aria-expanded="false"]))

    assert has_element?(
             lv,
             ~s(#site-switcher-menu a[href="/sites/#{other.public_id}/posts"]),
             "Other blog"
           )

    assert has_element?(
             lv,
             ~s(#site-switcher-menu a[aria-current="page"][href="/sites/#{site.public_id}/posts"])
           )

    refute has_element?(lv, ~s(#site-switcher-menu a[href="/sites/#{foreign.public_id}/posts"]))
    assert has_element?(lv, ~s(#all-sites-link[href="/"]), "All sites")
  end

  test "the top bar has a user menu and says Settings only once", %{conn: conn, site: site} do
    {:ok, lv, html} = live(conn, ~p"/sites/#{site.public_id}/posts")

    assert has_element?(lv, ~s(#user-menu-toggle[aria-label="Account"]))
    assert has_element?(lv, ~s(#user-menu-menu a[href="/users/settings"]), "Account settings")
    assert has_element?(lv, ~s(#user-menu-menu a[href="/users/log-out"]), "Log out")
    assert length(Regex.scan(~r/\bSettings\b/, html)) == 1
  end

  test "the deployment form renders in the shell", %{conn: conn, site: site, scope: scope} do
    target = Publishing.get_staging_target(scope)

    {:ok, lv, _html} =
      live(conn, ~p"/sites/#{site.public_id}/deployments/#{target.public_id}/edit")

    assert has_element?(lv, "#site-navigation a.active", "Deployments")
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
