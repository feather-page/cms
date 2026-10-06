defmodule FeatherWeb.SiteLive.IndexTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  test "redirects to the login page when logged out", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/")
  end

  describe "logged in" do
    setup [:register_and_log_in_user, :create_site_for_user]

    test "lists the user's sites and the navigation", %{conn: conn, site: site, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/")

      assert has_element?(lv, "#site-#{site.public_id}", site.title)
      assert has_element?(lv, "#site-#{site.public_id}", site.domain)

      assert has_element?(
               lv,
               ~s(#site-#{site.public_id} a[href="/sites/#{site.public_id}/posts"])
             )

      assert has_element?(lv, ~s(#new-site[href="/sites/new"]))
      assert has_element?(lv, "#current-user-email", user.email)
      assert has_element?(lv, ~s(a[href="/users/settings"]))
      assert has_element?(lv, ~s(a[href="/users/log-out"][data-method="delete"]))
    end

    # Rails: site_management.feature "View site list"
    test "lists several sites", %{conn: conn, scope: scope} do
      one = site_fixture(scope, title: "Blog One")
      two = site_fixture(scope, title: "Blog Two")

      {:ok, lv, _html} = live(conn, ~p"/")

      assert has_element?(lv, "#site-#{one.public_id}", "Blog One")
      assert has_element?(lv, "#site-#{two.public_id}", "Blog Two")
    end

    # Rails: site_management.feature "Only see own sites"
    test "does not list other users' sites", %{conn: conn} do
      other_site = site_fixture(nil, title: "Other Site")

      {:ok, lv, html} = live(conn, ~p"/")

      refute has_element?(lv, "#site-#{other_site.public_id}")
      refute html =~ "Other Site"
    end
  end

  test "a super admin sees all sites", %{conn: conn} do
    site = site_fixture(nil, title: "A Site Owned By Nobody Here")
    conn = log_in_user(conn, super_admin_fixture())

    {:ok, lv, _html} = live(conn, ~p"/")

    assert has_element?(lv, "#site-#{site.public_id}", "A Site Owned By Nobody Here")
  end

  test "shows an empty state", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    {:ok, lv, _html} = live(conn, ~p"/")
    assert has_element?(lv, "#no-sites")
    assert has_element?(lv, ~s(#no-sites a[href="/sites/new"]))
  end
end
