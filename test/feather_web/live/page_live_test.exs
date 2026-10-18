defmodule FeatherWeb.PageLiveTest do
  # Ports features/pages.feature and the navigation item actions.
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest
  import FeatherWeb.EditorHelpers

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

      lv |> element("#remove-from-navigation-#{first.public_id}-menu-item") |> render_click()
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

      # The first item cannot move up: disabled in the row and in the menu.
      assert has_element?(lv, "#move-up-#{first.public_id}[disabled]")
      assert has_element?(lv, "#move-up-#{first.public_id}-menu-item[disabled]")
      assert has_element?(lv, "#navigation-item-#{first.public_id}-menu-toggle")

      lv |> element("#move-up-#{second.public_id}-menu-item") |> render_click()
      assert nav_titles(scope) == ["Second", "First"]

      lv |> element("#add-to-navigation-#{other.public_id}-menu-item") |> render_click()
      assert nav_titles(scope) == ["Second", "First", "Other"]

      lv |> element("#remove-from-navigation-#{other.public_id}-menu-item") |> render_click()
      assert nav_titles(scope) == ["Second", "First"]
      assert has_element?(lv, "#delete-page-#{other.public_id}-menu-item[aria-haspopup=dialog]")

      assert asked(lv, "#delete-page-#{other.public_id}-menu-item").question ==
               "Delete the page “Other”?"
    end

    test "deletes a page", %{conn: conn, site: site, scope: scope} do
      page = page_fixture(scope, title: "Old Page")
      {:ok, lv, _html} = live(conn, pages_path(site))

      confirm_click(lv, "#delete-page-#{page.public_id}-menu-item")

      refute has_element?(lv, "#page-#{page.public_id}")
      assert_raise Ecto.NoResultsError, fn -> Content.get_page!(scope, page.public_id) end
    end

    test "deleting a page deleted in another tab refreshes the list", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      page = page_fixture(scope, title: "Old Page")
      {:ok, lv, _html} = live(conn, pages_path(site))
      {:ok, _} = Content.delete_page(scope, page)

      assert confirm_click(lv, "#delete-page-#{page.public_id}-menu-item") =~
               "This page no longer exists."

      refute has_element?(lv, "#page-#{page.public_id}")
    end

    test "navigation actions on a page deleted in another tab refresh the lists", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      first = page_fixture(scope, title: "First", add_to_navigation: true)
      second = page_fixture(scope, title: "Second", add_to_navigation: true)
      other = page_fixture(scope, title: "Other")
      {:ok, lv, _html} = live(conn, pages_path(site))
      {:ok, _} = Content.delete_page(scope, second)
      {:ok, _} = Content.delete_page(scope, other)

      assert lv |> element("#move-up-#{second.public_id}") |> render_click() =~
               "This page is no longer in the navigation."

      refute has_element?(lv, "#navigation-item-#{second.public_id}")
      refute has_element?(lv, "#page-#{other.public_id}")

      # A tab that still shows the other page.
      assert render_click(lv, "add_to_navigation", %{"id" => other.public_id}) =~
               "This page no longer exists."

      {:ok, _} = Content.delete_page(scope, first)

      assert lv
             |> element("#remove-from-navigation-#{first.public_id}-menu-item")
             |> render_click() =~
               "This page no longer exists."

      assert nav_titles(scope) == []
    end

    test "keeps focus on the moved row's move buttons", %{conn: conn, site: site, scope: scope} do
      first = page_fixture(scope, title: "First", add_to_navigation: true)
      second = page_fixture(scope, title: "Second", add_to_navigation: true)
      third = page_fixture(scope, title: "Third", add_to_navigation: true)
      {:ok, lv, _html} = live(conn, pages_path(site))

      # Second moves to the top, where its "Move up" is disabled: the browser
      # focuses the first enabled and visible one of these.
      lv |> element("#move-up-#{second.public_id}") |> render_click()
      s = second.public_id
      ids = ["move-up-#{s}", "move-down-#{s}", "navigation-item-#{s}-menu-toggle"]
      assert_push_event(lv, "focus", %{ids: ^ids})

      lv |> element("#move-down-#{first.public_id}") |> render_click()
      f = first.public_id
      ids = ["move-down-#{f}", "move-up-#{f}", "navigation-item-#{f}-menu-toggle"]
      assert_push_event(lv, "focus", %{ids: ^ids})

      assert nav_titles(scope) == ["Second", "Third", "First"]
      assert has_element?(lv, "#move-down-#{first.public_id}[disabled]")
      refute has_element?(lv, "#move-down-#{third.public_id}[disabled]")
    end

    test "showing and hiding a page keeps focus on its moved row", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      page = page_fixture(scope, title: "About")
      {:ok, lv, _html} = live(conn, pages_path(site))
      id = page.public_id

      # Lucide list-plus (a list with +) and list-minus (with −), not the preview's eye.
      assert has_element?(lv, ~s(#add-to-navigation-#{id} path[d="M18 9v6"]))

      lv |> element("#add-to-navigation-#{id}") |> render_click()
      ids = ["navigation-item-#{id}-menu-toggle"]
      assert_push_event(lv, "focus", %{ids: ^ids})
      assert has_element?(lv, ~s(#remove-from-navigation-#{id}-menu-item path[d="M21 12h-6"]))
      refute has_element?(lv, ~s(#remove-from-navigation-#{id}-menu-item path[d="M18 9v6"]))

      lv |> element("#remove-from-navigation-#{id}-menu-item") |> render_click()
      ids = ["add-to-navigation-#{id}", "page-#{id}-menu-toggle"]
      assert_push_event(lv, "focus", %{ids: ^ids})
      assert has_element?(lv, "#page-#{id}")
    end

    test "hiding a page that lands on another page of the list focuses the list", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      for n <- 1..20, do: page_fixture(scope, title: "Page #{n}")
      page = page_fixture(scope, title: "Zebra", add_to_navigation: true)
      {:ok, lv, _html} = live(conn, pages_path(site))

      lv |> element("#remove-from-navigation-#{page.public_id}-menu-item") |> render_click()

      refute has_element?(lv, "#page-#{page.public_id}")
      assert_push_event(lv, "focus", %{ids: ["other-pages"]})
      assert has_element?(lv, ~s(section#other-pages[tabindex="-1"]))
    end
  end

  describe "form" do
    test "creates a page with the first input that gives it a slug", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      {:ok, lv, _html} = live(conn, pages_path(site) <> "/new")

      lv
      |> element("#page-content-editor")
      |> render_hook("sync", %{
        "lock_version" => nil,
        "order" => nil,
        "blocks" => [paragraph_node("block00001", "Hi, I am me.")]
      })

      assert_reply(lv, %{status: "invalid"})
      assert Content.get_page_by_slug(scope, "/about") == nil

      lv
      |> element("#page-form")
      |> render_change(%{"page" => %{"title" => "About"}, "_target" => ["page", "title"]})

      page = Content.get_page_by_slug(scope, "/about")
      assert page.title == "About"
      assert Content.draft?(page)
      assert_patch(lv, pages_path(site) <> "/#{page.public_id}/edit")
      assert has_element?(lv, ~s(#page-content-editor[data-lock-version="#{page.lock_version}"]))

      # The editor, refused before, sends everything once the page exists.
      lv
      |> element("#page-content-editor")
      |> render_hook("sync", %{
        "lock_version" => page.lock_version,
        "order" => ["block00001"],
        "blocks" => [paragraph_node("block00001", "Hi, I am me.")]
      })

      assert_reply(lv, %{status: "saved"})
      assert [%{"text" => "Hi, I am me."}] = Content.get_page!(scope, page.public_id).content
    end

    test "creates the homepage", %{conn: conn, site: site, scope: scope} do
      {:ok, _homepage} = Content.delete_page(scope, Content.get_homepage(scope))
      refute Content.get_homepage(scope)

      {:ok, lv, _html} = live(conn, pages_path(site) <> "/new")

      lv |> form("#page-form", page: %{title: "Welcome", slug: "/"}) |> render_change()

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
      |> render_change()

      page = Content.get_page!(scope, page.public_id)
      assert page.title == "Get in Touch"
      assert page.page_type == "books"
    end

    test "adds the page to the navigation", %{conn: conn, site: site, scope: scope} do
      page = page_fixture(scope, title: "Services")
      {:ok, lv, _html} = live(conn, pages_path(site) <> "/#{page.public_id}/edit")

      lv |> form("#page-form", page: %{add_to_navigation: "true"}) |> render_change()

      assert Content.get_page!(scope, page.public_id).add_to_navigation
      assert has_element?(lv, "#page_add_to_navigation[checked]")
      refute has_element?(lv, "#status-badge")
    end

    test "removes the page from the navigation", %{conn: conn, site: site, scope: scope} do
      page = page_fixture(scope, title: "Services", add_to_navigation: true)
      {:ok, lv, _html} = live(conn, pages_path(site) <> "/#{page.public_id}/edit")

      assert has_element?(
               lv,
               ~s(input[type="hidden"][name="page[add_to_navigation]"][value="false"][form="page-form"])
             )

      lv
      |> element("#page-form")
      |> render_change(%{"page" => %{"add_to_navigation" => "false"}})

      refute Content.get_page!(scope, page.public_id).add_to_navigation
      assert nav_titles(scope) == []
      refute has_element?(lv, "#page_add_to_navigation[checked]")
    end

    test "shows validation errors without saving the invalid field", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      {:ok, lv, _html} = live(conn, pages_path(site) <> "/new")

      html = lv |> form("#page-form", page: %{title: "No slug", slug: ""}) |> render_change()
      assert html =~ "Can&#39;t be blank"
      assert has_element?(lv, ~s(#page-content-editor[data-form-status="invalid"]))
      assert Enum.map(Content.list_pages(scope), & &1.title) == ["Home"]

      page = page_fixture(scope, title: "Services", slug: "/services")
      {:ok, lv, _html} = live(conn, pages_path(site) <> "/#{page.public_id}/edit")

      lv |> form("#page-form", page: %{title: "Our services", slug: "/"}) |> render_change()

      assert has_element?(lv, "#slug-field .text-error-ink", "Has already been taken")

      assert %{title: "Our services", slug: "/services"} =
               Content.get_page!(scope, page.public_id)
    end

    test "unpublishes a page", %{conn: conn, site: site, scope: scope} do
      page = page_fixture(scope, title: "Services")
      {:ok, lv, _html} = live(conn, pages_path(site) <> "/#{page.public_id}/edit")
      assert has_element?(lv, "#publication-badge", "Published")

      lv |> element("#unpublish-page") |> render_click()

      assert has_element?(lv, "#publication-badge", "Draft")
      refute has_element?(lv, "#unpublish-page")
      assert Content.draft?(Content.get_page!(scope, page.public_id))
    end

    test "publishes and discards the changes of a page", %{conn: conn, site: site, scope: scope} do
      page = page_fixture(scope, title: "Services")
      edit_path = pages_path(site) <> "/#{page.public_id}/edit"
      {:ok, lv, _html} = live(conn, edit_path)
      assert has_element?(lv, "#publication-badge", "Published")
      assert has_element?(lv, "#version-1", "Published")

      lv |> form("#page-form", page: %{title: "Our services"}) |> render_change()

      html =
        lv |> element("#page-content-editor") |> render_hook("publish", %{"editor" => "saved"})

      assert html =~ "Page was published."
      assert has_element?(lv, "#version-2", "Published")

      {:ok, _page} =
        Content.update_page(scope, Content.get_page!(scope, page.public_id), %{title: "Draft"})

      {:ok, lv, _html} = live(conn, edit_path)
      assert has_element?(lv, "#publication-badge", "Changes not published")

      {:ok, _lv, _html} =
        lv |> confirm_click("#discard-page") |> follow_redirect(conn, edit_path)

      assert Content.get_page!(scope, page.public_id).title == "Our services"
    end

    test "restores an earlier version of a page", %{conn: conn, site: site, scope: scope} do
      page = page_fixture(scope, title: "Services")
      {:ok, page} = Content.update_page(scope, page, %{title: "Our services"})
      {:ok, page} = Content.publish(scope, page)
      edit_path = pages_path(site) <> "/#{page.public_id}/edit"
      {:ok, lv, _html} = live(conn, edit_path)

      {:ok, lv, _html} =
        lv |> confirm_click("#restore-version-1") |> follow_redirect(conn, edit_path)

      assert has_element?(lv, "#page_title", "Services")
      assert has_element?(lv, "#version-2", "Published")
    end

    test "a new page is a draft", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, pages_path(site) <> "/new")
      lv |> form("#page-form", page: %{title: "New", slug: "/new"}) |> render_change()
      assert Content.draft?(Content.get_page_by_slug(scope, "/new"))
    end

    test "marks pages in the navigation and deletes the page", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      page = page_fixture(scope, title: "Services")
      {:ok, _item} = Sites.add_to_navigation(scope, page)
      {:ok, lv, _html} = live(conn, pages_path(site) <> "/#{page.public_id}/edit")

      assert has_element?(lv, "h1", "Services")
      assert has_element?(lv, "#page_add_to_navigation[checked]")
      refute has_element?(lv, "#status-badge")

      assert asked(lv, "#delete-page").text ==
               "Removes the page from Feather. It stays on the live site until the next deploy."

      {:ok, _lv, html} =
        lv |> confirm_click("#delete-page") |> follow_redirect(conn, pages_path(site))

      assert html =~ "Page was successfully deleted."
      assert_raise Ecto.NoResultsError, fn -> Content.get_page!(scope, page.public_id) end
      assert nav_titles(scope) == []
    end

    test "deleting a page deleted in another tab goes back to the list", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      page = page_fixture(scope, title: "Services")
      {:ok, lv, _html} = live(conn, pages_path(site) <> "/#{page.public_id}/edit")
      {:ok, _} = Content.delete_page(scope, page)

      {:ok, _lv, html} =
        lv |> confirm_click("#delete-page") |> follow_redirect(conn, pages_path(site))

      assert html =~ "This page no longer exists."
    end

    test "a page of another site is not found", %{conn: conn, site: site} do
      other = page_fixture(site_scope_fixture())

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, pages_path(site) <> "/#{other.public_id}/edit")
      end
    end
  end

  test "autosaves the content of a page", %{conn: conn, site: site, scope: scope} do
    page = page_fixture(scope, content: [paragraph("About")])
    [%{"id" => id}] = page.content
    {:ok, lv, _html} = live(conn, pages_path(site) <> "/#{page.public_id}/edit")

    lv
    |> element("#page-content-editor")
    |> render_hook("sync", sync_params(page, nil, [paragraph_node(id, "About me")]))

    assert_reply(lv, %{status: "saved"})
    assert [%{"text" => "About me"}] = Feather.Repo.reload!(page).content
  end

  defp nav_titles(scope), do: scope |> Sites.list_navigation_items() |> Enum.map(& &1.page.title)
end
