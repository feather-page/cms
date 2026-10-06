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
