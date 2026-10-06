defmodule FeatherWeb.SiteLive.SettingsTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.Sites

  test "redirects to the login page when logged out", %{conn: conn} do
    site = site_fixture()

    assert {:error, {:redirect, %{to: "/users/log-in"}}} =
             live(conn, ~p"/sites/#{site.public_id}/settings")
  end

  describe "access" do
    setup :register_and_log_in_user

    test "a site the user is not a member of is not found", %{conn: conn} do
      site = site_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/sites/#{site.public_id}/settings")
      end
    end

    test "an unknown site is not found", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/sites/doesnotexist/settings") end
    end
  end

  test "a super admin may edit any site", %{conn: conn} do
    site = site_fixture()
    conn = log_in_user(conn, super_admin_fixture())

    {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")
    assert has_element?(lv, "#site-form")
  end

  describe "site form" do
    setup [:register_and_log_in_user, :create_site_for_user]

    # Rails: site_management.feature "Edit a site"
    test "updates the title and the other settings", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      html =
        lv
        |> form("#site-form",
          site: %{
            title: "My New Blog",
            domain: "http://Updated.de/",
            language_code: "de",
            copyright: "© {{CurrentYear}} Updated"
          }
        )
        |> render_submit()

      assert html =~ "Site was successfully updated."
      assert html =~ "My New Blog"

      site = Sites.get_site!(scope, site.public_id)
      assert site.title == "My New Blog"
      assert site.domain == "updated.de"
      assert site.language_code == "de"
      assert site.copyright == "© {{CurrentYear}} Updated"
    end

    # Rails: site_management.feature "Change site emoji"
    test "changes the emoji", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      lv |> form("#site-form", site: %{emoji: "🚀"}) |> render_submit()

      assert has_element?(lv, ~s(#site_emoji[value="🚀"]))
      assert Sites.get_site!(scope, site.public_id).emoji == "🚀"
    end

    test "shows the copyright placeholder hint", %{conn: conn, site: site} do
      {:ok, _lv, html} = live(conn, ~p"/sites/#{site.public_id}/settings")
      assert html =~ "{{CurrentYear}}"
    end

    test "shows validation errors and keeps the site", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      assert lv |> form("#site-form", site: %{emoji: "abc"}) |> render_change() =~
               "must be an emoji"

      assert lv |> form("#site-form", site: %{domain: ""}) |> render_change() =~
               "can&#39;t be blank"

      assert lv |> form("#site-form", site: %{title: ""}) |> render_submit() =~
               "can&#39;t be blank"

      assert Sites.get_site!(scope, site.public_id).title == site.title
    end
  end

  describe "social media links" do
    setup [:register_and_log_in_user, :create_site_for_user]

    test "shows a hint when there are no links", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")
      assert has_element?(lv, "#no-social-media-links")
    end

    test "lists the site's links", %{conn: conn, site: site, scope: scope} do
      link = social_media_link_fixture(scope)
      other = social_media_link_fixture(site_scope_fixture(), url: "https://github.com/other")

      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      refute has_element?(lv, "#no-social-media-links")
      assert has_element?(lv, "#social_media_links-#{link.id}", "https://github.com/johndoe")
      refute has_element?(lv, "#social_media_links-#{other.id}")
    end

    test "picking a service prefills the name and the URL placeholder", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      lv
      |> form("#social-media-link-form", social_media_link: %{url: "https://x.example/me"})
      |> render_change()

      lv |> element("#service-mastodon") |> render_click()

      assert has_element?(lv, "#service-mastodon.active")
      assert has_element?(lv, ~s(#social_media_link_icon[value="mastodon"]))
      assert has_element?(lv, ~s(#social_media_link_name[value="Mastodon"]))

      assert has_element?(
               lv,
               ~s(#social_media_link_url[placeholder="https://mastodon.social/@johndoe"])
             )

      # What was typed into the URL field is kept.
      assert has_element?(lv, ~s(#social_media_link_url[value="https://x.example/me"]))
    end

    test "creates a link", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      lv |> element("#service-github") |> render_click()

      html =
        lv
        |> form("#social-media-link-form",
          social_media_link: %{name: "My GitHub", url: "https://github.com/me"}
        )
        |> render_submit()

      assert html =~ "Social media link was successfully created."
      assert [link] = Sites.list_social_media_links(scope)
      assert link.icon == "github"
      assert link.name == "My GitHub"
      assert has_element?(lv, "#social_media_links-#{link.id}", "https://github.com/me")
      refute has_element?(lv, "#no-social-media-links")
      # The form is reset.
      refute has_element?(lv, "#service-github.active")
    end

    test "requires a service, a name and a URL", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      html =
        lv
        |> form("#social-media-link-form", social_media_link: %{name: "", url: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
      assert has_element?(lv, "#social-media-link-icon-error")
      assert Sites.list_social_media_links(scope) == []
    end

    test "deletes a link", %{conn: conn, site: site, scope: scope} do
      link = social_media_link_fixture(scope)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      html = lv |> element("#delete-social_media_links-#{link.id}") |> render_click()

      assert html =~ "Social media link was successfully deleted."
      refute has_element?(lv, "#social_media_links-#{link.id}")
      assert has_element?(lv, "#no-social-media-links")
      assert Sites.list_social_media_links(scope) == []
    end

    @tag :capture_log
    test "cannot delete another site's link", %{conn: conn, site: site} do
      other_scope = site_scope_fixture()
      other = social_media_link_fixture(other_scope)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      Process.flag(:trap_exit, true)

      assert {{%Ecto.NoResultsError{}, _}, _} =
               catch_exit(render_hook(lv, "delete_link", %{"id" => other.id}))

      assert [_] = Sites.list_social_media_links(other_scope)
    end
  end
end
