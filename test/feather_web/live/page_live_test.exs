defmodule FeatherWeb.PageLiveTest do
  # Ports features/pages.feature and the navigation item actions.
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest
  import FeatherWeb.EditorJsHelpers

  alias Feather.{Content, Sites}

  setup [:register_and_log_in_user, :create_site_for_user]

  defp pages_path(site), do: ~p"/sites/#{site.public_id}/pages"

  describe "index" do
    test "separates pages in the navigation from the other pages", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      about = page_fixture(scope, title: "About", add_to_navigation: true)
      imprint = page_fixture(scope, title: "Imprint")
      homepage = Content.get_homepage(scope)

      {:ok, lv, _html} = live(conn, pages_path(site))

      assert has_element?(lv, "#navigation-item-#{about.public_id}", "About")
      refute has_element?(lv, "#page-#{about.public_id}")
      assert has_element?(lv, "#page-#{imprint.public_id}", "Imprint")
      assert has_element?(lv, "#page-#{homepage.public_id}", "Home")
    end

    test "paginates the other pages", %{conn: conn, site: site, scope: scope} do
      for n <- 1..25, do: page_fixture(scope, title: "Page #{n}", slug: "/page-#{n}")

      {:ok, lv, _html} = live(conn, pages_path(site))
      assert has_element?(lv, "#pagination")
    end

    test "adds, moves and removes navigation items and publishes the site", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      first = page_fixture(scope, title: "First", add_to_navigation: true)
      second = page_fixture(scope, title: "Second")

      {:ok, lv, _html} = live(conn, pages_path(site))

      lv |> element("#add-to-navigation-#{second.public_id}") |> render_click()
      assert has_element?(lv, "#navigation-item-#{second.public_id}")
      assert nav_titles(scope) == ["First", "Second"]
      assert has_element?(lv, "#move-up-#{first.public_id}[disabled]")

      lv |> element("#move-up-#{second.public_id}") |> render_click()
      assert nav_titles(scope) == ["Second", "First"]

      lv |> element("#move-down-#{second.public_id}") |> render_click()
      assert nav_titles(scope) == ["First", "Second"]

      lv |> element("#remove-from-navigation-#{first.public_id}") |> render_click()
      assert nav_titles(scope) == ["Second"]
      assert has_element?(lv, "#page-#{first.public_id}")
    end

    test "each row links to the page and folds its actions into a menu on narrow screens", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      first = page_fixture(scope, title: "First", add_to_navigation: true)
      second = page_fixture(scope, title: "Second", add_to_navigation: true)
      other = page_fixture(scope, title: "Other")

      {:ok, lv, _html} = live(conn, pages_path(site))

      assert has_element?(
               lv,
               ~s(#navigation-item-#{first.public_id} a[href="#{pages_path(site)}/#{first.public_id}/edit"])
             )

      # The first item cannot move up: hidden in the row, left out of the menu.
      assert has_element?(lv, "#move-up-#{first.public_id}[disabled]")
      refute has_element?(lv, "#move-up-#{first.public_id}-menu-item")
      assert has_element?(lv, "#navigation-item-#{first.public_id}-menu-toggle")

      lv |> element("#move-up-#{second.public_id}-menu-item") |> render_click()
      assert nav_titles(scope) == ["Second", "First"]

      lv |> element("#add-to-navigation-#{other.public_id}-menu-item") |> render_click()
      assert nav_titles(scope) == ["Second", "First", "Other"]

      lv |> element("#remove-from-navigation-#{other.public_id}-menu-item") |> render_click()
      assert nav_titles(scope) == ["Second", "First"]
      assert has_element?(lv, "#delete-page-#{other.public_id}-menu-item[data-confirm]")
    end

    test "deletes a page", %{conn: conn, site: site, scope: scope} do
      page = page_fixture(scope, title: "Old Page")
      {:ok, lv, _html} = live(conn, pages_path(site))

      lv |> element("#delete-page-#{page.public_id}") |> render_click()

      refute has_element?(lv, "#page-#{page.public_id}")
      assert_raise Ecto.NoResultsError, fn -> Content.get_page!(scope, page.public_id) end
    end
  end

  describe "form" do
    test "creates a page", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, pages_path(site) <> "/new")

      {:ok, _lv, html} =
        lv
        |> form("#page-form", page: %{title: "About Me", slug: "/about"})
        |> render_submit(%{"page" => %{"content" => editor_json("Hi, I am me.")}})
        |> follow_redirect(conn, pages_path(site))

      assert html =~ "About Me"
      page = Content.get_page_by_slug(scope, "/about")
      assert page.title == "About Me"
      assert [%{"text" => "Hi, I am me."}] = page.content
    end

    test "creates the homepage", %{conn: conn, site: site, scope: scope} do
      {:ok, _homepage} = Content.delete_page(scope, Content.get_homepage(scope))
      refute Content.get_homepage(scope)

      {:ok, lv, _html} = live(conn, pages_path(site) <> "/new")

      lv
      |> form("#page-form", page: %{title: "Welcome", slug: "/"})
      |> render_submit()

      assert Content.get_homepage(scope).title == "Welcome"
    end

    test "suggests a slug from the title", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, pages_path(site) <> "/new")

      lv
      |> element("#page-form")
      |> render_change(%{"page" => %{"title" => "Get in Touch"}, "_target" => ["page", "title"]})

      assert has_element?(lv, ~s(#page_slug[value="/get-in-touch"]))
    end

    test "edits a page", %{conn: conn, site: site, scope: scope} do
      page = page_fixture(scope, title: "Contact")
      {:ok, lv, _html} = live(conn, pages_path(site) <> "/#{page.public_id}/edit")

      lv
      |> form("#page-form", page: %{title: "Get in Touch", page_type: "books"})
      |> render_submit()

      page = Content.get_page!(scope, page.public_id)
      assert page.title == "Get in Touch"
      assert page.page_type == "books"
    end

    test "adds the page to the navigation", %{conn: conn, site: site, scope: scope} do
      page = page_fixture(scope, title: "Services")
      {:ok, lv, _html} = live(conn, pages_path(site) <> "/#{page.public_id}/edit")

      lv
      |> form("#page-form", page: %{add_to_navigation: "true"})
      |> render_submit()

      assert Content.get_page!(scope, page.public_id).add_to_navigation
    end

    test "shows validation errors", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, pages_path(site) <> "/new")

      html = lv |> form("#page-form", page: %{title: "No slug", slug: ""}) |> render_submit()
      assert html =~ "can&#39;t be blank"
    end

    test "a page of another site is not found", %{conn: conn, site: site} do
      other = page_fixture(site_scope_fixture())

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, pages_path(site) <> "/#{other.public_id}/edit")
      end
    end
  end

  defp nav_titles(scope), do: scope |> Sites.list_navigation_items() |> Enum.map(& &1.page.title)
end
