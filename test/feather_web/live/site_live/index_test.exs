defmodule FeatherWeb.SiteLive.IndexTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  test "redirects to the login page when logged out", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/")
  end

  describe "logged in" do
    setup [:register_and_log_in_user, :create_site_for_user]

    test "lists the user's sites and the navigation", %{conn: conn, site: site, user: user} do
      other_site = site_fixture(nil, title: "Not mine")

      {:ok, lv, html} = live(conn, ~p"/")

      assert has_element?(lv, "#site-#{site.public_id}", site.title)
      refute html =~ other_site.title
      assert has_element?(lv, "#current-user-email", user.email)
      assert has_element?(lv, ~s(a[href="/users/settings"]))
      assert has_element?(lv, ~s(a[href="/users/log-out"][data-method="delete"]))
    end
  end

  test "shows an empty state", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    {:ok, lv, _html} = live(conn, ~p"/")
    assert has_element?(lv, "#no-sites")
  end
end
