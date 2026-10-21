defmodule FeatherWeb.RedirectLiveTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.{Content, Redirects, Repo}
  alias Feather.Redirects.Redirect
  alias Feather.StaticSite.{Htaccess, Routes, SiteData}

  test "a site the user is not a member of is not found", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    site = site_fixture()

    assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/sites/#{site.public_id}/redirects") end
  end

  describe "redirects page" do
    setup [:register_and_log_in_user, :create_site_for_user]

    test "sits in the sidebar under Site after Settings", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      hrefs =
        lv
        |> render()
        |> LazyHTML.from_fragment()
        |> LazyHTML.query("nav[aria-label=Main] a")
        |> LazyHTML.attribute("href")
        |> Enum.uniq()

      settings = Enum.find_index(hrefs, &(&1 == "/sites/#{site.public_id}/settings"))
      assert Enum.at(hrefs, settings + 1) == "/sites/#{site.public_id}/redirects"

      assert has_element?(lv, ~s(nav[aria-label=Main] a[href$="/redirects"]), "Redirects")
    end

    test "shows an empty state without redirects", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/redirects")

      assert has_element?(lv, "#no-redirects")
      assert has_element?(lv, "#redirect-form")
    end

    test "lists the redirects, marking temporary and inactive ones", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      post = post_fixture(scope, %{title: "Now", slug: "/now"})
      page = page_fixture(scope, %{slug: "/target"})

      {:ok, to_post} =
        Redirects.create_redirect(scope, %{
          old_path: "/current",
          target: "/now/",
          kind: "temporary"
        })

      {:ok, to_page} = Redirects.create_redirect(scope, %{old_path: "/old", target: "/target"})
      {:ok, _} = Content.unpublish(scope, page)

      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/redirects")

      assert has_element?(lv, "#redirects-#{to_post.public_id}", "/current")
      assert has_element?(lv, "#redirects-#{to_post.public_id}", post.title)
      assert has_element?(lv, "#redirects-#{to_post.public_id} [data-kind=temporary]")
      refute has_element?(lv, "#redirects-#{to_post.public_id} [data-inactive]")
      assert has_element?(lv, "#redirects-#{to_page.public_id} [data-inactive]")
      refute has_element?(lv, "#redirects-#{to_page.public_id} [data-kind=temporary]")
    end

    test "shows the URL the target is published at, not its unpublished slug",
         %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope, %{slug: "/published"})

      {:ok, redirect} =
        Redirects.create_redirect(scope, %{old_path: "/old", target: "/published"})

      {:ok, _} = Content.update_post(scope, post, %{slug: "/draft-slug"})

      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/redirects")
      assert has_element?(lv, "#redirects-#{redirect.public_id}", "to /published/")

      lv |> element("#edit-redirect-#{redirect.public_id}") |> render_click()
      assert lv |> element("#redirect_target") |> render() =~ ~s(value="/published/")
    end

    test "creates a redirect", %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope, %{slug: "/rule-of-72"})
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/redirects")

      html =
        lv
        |> form("#redirect-form",
          redirect: %{old_path: "/posts/rule-of-72/", target: "/rule-of-72/", kind: "permanent"}
        )
        |> render_submit()

      assert html =~ "Redirect was successfully created."

      assert [%{old_path: "/posts/rule-of-72", post_id: post_id} = redirect] =
               Redirects.list_redirects(scope)

      assert post_id == post.id
      assert has_element?(lv, "#redirects-#{redirect.public_id}", "/posts/rule-of-72")
      refute lv |> element("#redirect_old_path") |> render() =~ "value="
    end

    test "shows why an old path or a target is refused", %{conn: conn, site: site, scope: scope} do
      page_fixture(scope, %{slug: "/about", draft: true})
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/redirects")

      lv
      |> form("#redirect-form", redirect: %{old_path: "/about/", target: "/nowhere"})
      |> render_change()

      assert has_element?(lv, "#redirect-form", "Is already a URL of the site")

      lv
      |> form("#redirect-form", redirect: %{old_path: "/about/", target: "/nowhere"})
      |> render_submit()

      assert has_element?(lv, "#redirect-form", "Does not lead to anything on the site")
      assert Redirects.list_redirects(scope) == []
    end

    test "a pasted old path matches with and without a trailing slash",
         %{conn: conn, site: site, scope: scope} do
      post = post_fixture(scope, %{title: "Rule of 72", slug: "/rule-of-72"})
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/redirects")

      html =
        lv
        |> form("#paste-redirects-form", paste: %{lines: "/posts/rule-of-72 /rule-of-72/"})
        |> render_submit()

      assert html =~ "1 redirect was created."

      assert [%{old_path: "/posts/rule-of-72", kind: :permanent, post_id: post_id} = redirect] =
               Redirects.list_redirects(scope)

      assert post_id == post.id
      assert has_element?(lv, "#redirects-#{redirect.public_id}", "Rule of 72")
      refute has_element?(lv, "#paste-errors")

      site = Repo.reload!(site)

      assert Htaccess.render(Routes.new(site), SiteData.redirects(SiteData.load(site))) =~
               "RewriteRule ^posts/rule\\-of\\-72/?$ /rule-of-72/ [R=301,L]"
    end

    test "a pasted list saves the valid lines and shows the invalid ones with their error",
         %{conn: conn, site: site, scope: scope} do
      post_fixture(scope, %{slug: "/rule-of-72"})
      page_fixture(scope, %{slug: "/about"})
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/redirects")

      lines = "/posts/rule-of-72 /rule-of-72/\n/about/ /\n/old /nowhere\n"

      html =
        lv
        |> form("#paste-redirects-form", paste: %{lines: lines})
        |> render_submit()

      assert html =~ "1 redirect was created."
      assert [%{old_path: "/posts/rule-of-72"}] = Redirects.list_redirects(scope)

      assert has_element?(lv, "#paste-errors li", "/about/ /")
      assert has_element?(lv, "#paste-errors li", "Old path is already a URL of the site")
      assert has_element?(lv, "#paste-errors li", "/old /nowhere")
      assert has_element?(lv, "#paste-errors li", "Target does not lead to anything on the site")
      refute has_element?(lv, "#paste-errors li:nth-child(3)")

      assert lv |> element("#paste_lines") |> render() =~ "/about/ /\n/old /nowhere</textarea>"
    end

    test "clears pasted lines that were all added", %{conn: conn, site: site, scope: scope} do
      post_fixture(scope, %{slug: "/rule-of-72"})
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/redirects")
      params = %{paste: %{lines: "/posts/rule-of-72 /rule-of-72/"}}

      lv |> form("#paste-redirects-form", params) |> render_change()
      assert lv |> element("#paste_lines") |> render() =~ "/posts/rule-of-72 /rule-of-72/"

      lv |> form("#paste-redirects-form", params) |> render_submit()
      refute lv |> element("#paste_lines") |> render() =~ "rule-of-72"
    end

    test "edits a redirect", %{conn: conn, site: site, scope: scope} do
      {:ok, redirect} = Redirects.create_redirect(scope, %{old_path: "/old", target: "/"})
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/redirects")

      lv |> element("#edit-redirect-#{redirect.public_id}") |> render_click()
      assert_patch(lv, ~p"/sites/#{site.public_id}/redirects/#{redirect.public_id}/edit")
      assert lv |> element("#redirect_old_path") |> render() =~ ~s(value="/old")

      html =
        lv
        |> form("#redirect-form", redirect: %{target: "/feed.xml", kind: "temporary"})
        |> render_submit()

      assert html =~ "Redirect was successfully updated."
      assert_patch(lv, ~p"/sites/#{site.public_id}/redirects")

      assert [%{old_path: "/old", target_path: "/feed.xml", kind: :temporary}] =
               Redirects.list_redirects(scope)
    end

    test "saving a redirect deleted elsewhere says it no longer exists",
         %{conn: conn, site: site, scope: scope} do
      {:ok, redirect} = Redirects.create_redirect(scope, %{old_path: "/old", target: "/"})

      {:ok, lv, _html} =
        live(conn, ~p"/sites/#{site.public_id}/redirects/#{redirect.public_id}/edit")

      {:ok, _} = Redirects.delete_redirect(scope, redirect)

      html =
        lv
        |> form("#redirect-form", redirect: %{target: "/feed.xml"})
        |> render_submit()

      assert html =~ "This redirect no longer exists."
      assert_patch(lv, ~p"/sites/#{site.public_id}/redirects")
      refute has_element?(lv, "#redirects-#{redirect.public_id}")
    end

    test "deletes a redirect after confirmation", %{conn: conn, site: site, scope: scope} do
      {:ok, redirect} = Redirects.create_redirect(scope, %{old_path: "/old", target: "/"})
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/redirects")

      html = confirm_click(lv, "#delete-redirect-#{redirect.public_id}-menu-item")

      assert html =~ "Redirect was successfully deleted."
      refute has_element?(lv, "#redirects-#{redirect.public_id}")
      assert Redirects.list_redirects(scope) == []
    end

    test "cannot edit or delete a redirect of another site", %{conn: conn, site: site} do
      {:ok, other} =
        Redirects.create_redirect(site_scope_fixture(), %{old_path: "/old", target: "/"})

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/sites/#{site.public_id}/redirects/#{other.public_id}/edit")
      end

      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/redirects")

      assert render_hook(lv, "delete", %{"id" => other.public_id}) =~
               "This redirect no longer exists."

      assert Repo.get(Redirect, other.id)
    end
  end
end
