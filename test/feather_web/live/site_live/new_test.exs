defmodule FeatherWeb.SiteLive.NewTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.{Publishing, Sites}
  alias Feather.Accounts.Scope

  test "redirects to the login page when logged out", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/sites/new")
  end

  describe "logged in" do
    setup :register_and_log_in_user

    test "the sites overview links to the form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      assert {:ok, _lv, html} =
               lv
               |> element("#new-site")
               |> render_click()
               |> follow_redirect(conn, ~p"/sites/new")

      assert html =~ "New site"
    end

    test "offers English and German first", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/sites/new")

      assert lv |> element("#site_language_code option:nth-child(1)") |> render() =~
               ~s(value="en")

      assert lv |> element("#site_language_code option:nth-child(2)") |> render() =~
               ~s(value="de")
    end

    # Rails: site_management.feature "Create a new site"
    test "creates a site and goes to its posts", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/sites/new")

      lv
      |> form("#site-form",
        site: %{title: "My Blog", domain: "https://MyBlog.com/about", language_code: "de"}
      )
      |> render_submit()

      scope = Scope.for_user(user)
      assert [site] = Sites.list_sites(scope)
      assert site.title == "My Blog"
      assert site.domain == "myblog.com"
      assert site.language_code == "de"

      assert_redirect(lv, "/sites/#{site.public_id}/posts")
      assert [%{type: "staging"}] = Publishing.list_targets(Scope.put_site(scope, site))
    end

    test "shows validation errors", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/sites/new")

      html =
        lv
        |> form("#site-form", site: %{title: "", domain: "not a domain!"})
        |> render_change()

      assert html =~ "can&#39;t be blank"
      assert html =~ "may only contain letters, digits, dots and dashes"

      html =
        lv
        |> form("#site-form", site: %{title: "", domain: "example.com"})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
      assert Sites.list_sites(Scope.for_user(user)) == []
    end

    test "rejects a domain that is already taken", %{conn: conn} do
      site_fixture(nil, domain: "taken.example.com")
      {:ok, lv, _html} = live(conn, ~p"/sites/new")

      html =
        lv
        |> form("#site-form", site: %{title: "Mine", domain: "taken.example.com"})
        |> render_submit()

      assert html =~ "has already been taken"
    end
  end
end
