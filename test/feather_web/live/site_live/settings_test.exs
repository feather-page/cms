defmodule FeatherWeb.SiteLive.SettingsTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Feather.Sites
  alias Feather.Sites.Site

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

    test "keeps the bio", %{conn: conn, site: site, scope: scope} do
      {:ok, _site} = Sites.update_site(scope, site, %{bio: "I build websites."})
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      lv |> form("#site-form", site: %{title: "Renamed"}) |> render_submit()

      site = Sites.get_site!(scope, site.public_id)
      assert site.title == "Renamed"
      assert site.bio == "I build websites."
    end

    # Rails: site_management.feature "Change site emoji"
    test "changes the emoji", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      lv |> form("#site-form", site: %{emoji: "🚀"}) |> render_submit()

      assert has_element?(lv, ~s(#site_emoji[value="🚀"]))
      assert Sites.get_site!(scope, site.public_id).emoji == "🚀"
    end

    test "the site form saves without a cancel button", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")
      assert has_element?(lv, "#site-form button[type=submit]", "Save")
      refute has_element?(lv, "#site-form a", "Cancel")
      refute has_element?(lv, "#site-form button", "Cancel")
    end

    test "shows the copyright placeholder hint", %{conn: conn, site: site} do
      {:ok, _lv, html} = live(conn, ~p"/sites/#{site.public_id}/settings")
      assert html =~ "{{CurrentYear}}"
    end

    test "shows validation errors and keeps the site", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      assert lv |> form("#site-form", site: %{emoji: "abc"}) |> render_change() =~
               "Must be an emoji"

      assert lv |> form("#site-form", site: %{domain: ""}) |> render_change() =~
               "Can&#39;t be blank"

      assert lv |> form("#site-form", site: %{title: ""}) |> render_submit() =~
               "Can&#39;t be blank"

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
      lv |> element("#add-link") |> render_click()
      assert has_element?(lv, "#selected-service", "Pick a service")
      assert has_element?(lv, ~s(#social_media_link_name[placeholder="Link name"]))

      lv
      |> form("#social-media-link-form", social_media_link: %{url: "https://x.example/me"})
      |> render_change()

      lv |> element("#service-mastodon") |> render_click()

      assert has_element?(lv, "#service-mastodon[aria-pressed=true]")
      assert has_element?(lv, "#selected-service", "Mastodon")
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
      lv |> element("#add-link") |> render_click()

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
      # The form closes and opens again empty.
      refute has_element?(lv, "#social-media-link-form")
      lv |> element("#add-link") |> render_click()
      refute has_element?(lv, "#service-github[aria-pressed=true]")
    end

    test "the link form is collapsed until asked for", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")
      refute has_element?(lv, "#social-media-link-form")

      lv |> element("#add-link") |> render_click()
      assert has_element?(lv, "#social-media-link-form")
      refute has_element?(lv, "#add-link")

      lv |> element("#service-github") |> render_click()
      lv |> element("#cancel-link") |> render_click()
      refute has_element?(lv, "#social-media-link-form")

      lv |> element("#add-link") |> render_click()
      refute has_element?(lv, "#service-github[aria-pressed=true]")
    end

    test "requires a service, a name and a URL", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")
      lv |> element("#add-link") |> render_click()

      html =
        lv
        |> form("#social-media-link-form", social_media_link: %{name: "", url: ""})
        |> render_submit()

      assert html =~ "Can&#39;t be blank"
      assert has_element?(lv, "#social-media-link-icon-error")
      assert Sites.list_social_media_links(scope) == []
    end

    test "deletes a link", %{conn: conn, site: site, scope: scope} do
      link = social_media_link_fixture(scope)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      html = confirm_click(lv, "#delete-social_media_links-#{link.id}-menu-item")

      assert html =~ "Social media link was successfully deleted."
      refute has_element?(lv, "#social_media_links-#{link.id}")
      assert has_element?(lv, "#no-social-media-links")
      assert Sites.list_social_media_links(scope) == []
    end

    test "cannot delete another site's link", %{conn: conn, site: site} do
      other_scope = site_scope_fixture()
      other = social_media_link_fixture(other_scope)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      assert render_hook(lv, "delete_link", %{"id" => other.id}) =~ "This link no longer exists."
      assert [_] = Sites.list_social_media_links(other_scope)
    end

    test "deleting a link deleted in another tab refreshes the list", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      link = social_media_link_fixture(scope)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")
      {:ok, _} = Sites.delete_social_media_link(scope, link)

      assert confirm_click(lv, "#delete-social_media_links-#{link.id}-menu-item") =~
               "This link no longer exists."

      refute has_element?(lv, "#social_media_links-#{link.id}")
      assert has_element?(lv, "#no-social-media-links")
    end
  end

  describe "mascots" do
    setup [:register_and_log_in_user, :create_site_for_user]

    defp upload_mascot(lv, slot, name \\ "mascot.png", content \\ nil) do
      content = content || File.read!(transparent_image_path(120, 40))

      lv
      |> file_input("#mascot-#{slot}-form", Site.mascot_assoc(slot), [
        %{name: name, content: content, type: "image/png"}
      ])
      |> render_upload(name)
    end

    defp mascot(scope, slot),
      do: Map.fetch!(Sites.preload_images(Sites.get_site!(scope, scope.site.public_id)), slot)

    test "shows three empty slots with the site emoji", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      assert has_element?(lv, "#mascots-hint", "shown by the feather.page theme")

      for slot <- ~w(footer post_end projects) do
        assert has_element?(lv, "#mascot-#{slot}-preview", site.emoji)
        refute has_element?(lv, "#mascot-#{slot}-preview img")
        assert has_element?(lv, "#mascot-#{slot}-form label", "Upload")
        refute has_element?(lv, "#remove-mascot-#{slot}")
      end
    end

    test "uploads a mascot", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      upload_mascot(lv, :footer, "mice.png")

      assert %Feather.Media.Image{filename: "mice.png"} =
               image = mascot(scope, :footer_mascot_image)

      assert has_element?(lv, ~s(#mascot-footer-preview img[src*="#{image.public_id}"]))
      assert has_element?(lv, "#mascot-footer-form label", "Replace")
      assert has_element?(lv, "#remove-mascot-footer")
      refute has_element?(lv, "#mascot-projects-preview img")
      assert render(lv) =~ "Footer mascot was successfully updated."
    end

    test "replaces a mascot", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      upload_mascot(lv, :post_end, "old.png")
      old = mascot(scope, :post_end_mascot_image)
      upload_mascot(lv, :post_end, "new.png")

      assert %{filename: "new.png"} = new = mascot(scope, :post_end_mascot_image)
      assert has_element?(lv, ~s(#mascot-post_end-preview img[src*="#{new.public_id}"]))
      refute Feather.Repo.get(Feather.Media.Image, old.id)
    end

    test "removes a mascot after confirming", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")
      upload_mascot(lv, :projects)
      image = mascot(scope, :projects_mascot_image)

      html = confirm_click(lv, "#remove-mascot-projects", "Remove the projects mascot?")

      assert html =~ "Projects mascot was successfully removed."
      assert mascot(scope, :projects_mascot_image) == nil
      refute Feather.Repo.get(Feather.Media.Image, image.id)
      assert has_element?(lv, "#mascot-projects-preview", site.emoji)
      refute has_element?(lv, "#remove-mascot-projects")
    end

    test "shows an error for a file that is not an image", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      upload_mascot(lv, :footer, "fake.png", "not an image")

      assert has_element?(lv, "#mascot-footer-error", "must be an image")
      assert mascot(scope, :footer_mascot_image) == nil
    end

    test "names the size limit for a file that is too big", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      lv
      |> file_input("#mascot-footer-form", :footer_mascot_image, [
        %{
          name: "big.png",
          content: :binary.copy("x", Feather.Media.max_byte_size() + 1),
          type: "image/png"
        }
      ])
      |> render_upload("big.png")

      lv |> element("#mascot-footer-form") |> render_change(%{})

      assert has_element?(lv, "#mascot-footer-error", "at most 25 MB")
    end

    test "accepts only PNG and WebP files", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      assert has_element?(
               lv,
               ~s(#mascot-footer-form input[type=file][accept=".png,.webp"])
             )
    end
  end

  describe "theme" do
    setup [:register_and_log_in_user, :create_site_for_user]

    test "offers the registered themes and saves the choice", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      assert has_element?(
               lv,
               ~s(#site-form select#site_theme option[value="feather"]),
               "feather.page"
             )

      assert has_element?(lv, ~s(#site_theme option[value="simple_sidebar"]), "Simple sidebar")
      assert has_element?(lv, ~s(#site_theme option[value="feather"][selected]))

      html = lv |> form("#site-form", site: %{theme: "simple_sidebar"}) |> render_submit()

      assert html =~ "Site was successfully updated."
      assert Sites.get_site!(scope, site.public_id).theme == "simple_sidebar"
    end
  end

  describe "portrait" do
    setup [:register_and_log_in_user, :create_site_for_user]

    defp upload_portrait(lv, name \\ "me.jpg", content \\ nil) do
      content = content || File.read!(test_image_path(60, 80, "jpg"))

      lv
      |> file_input("#portrait-form", :portrait_image, [
        %{name: name, content: content, type: "image/jpeg"}
      ])
      |> render_upload(name)
    end

    defp portrait(scope),
      do: Sites.preload_images(Sites.get_site!(scope, scope.site.public_id)).portrait_image

    test "shows an empty portrait slot with a hint on the themes", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      assert has_element?(lv, "#portrait-slots #portrait")
      assert has_element?(lv, "#portrait-hint", "Simple sidebar theme shows it on the home page")
      refute has_element?(lv, "#portrait-preview img")
      assert has_element?(lv, "#portrait-form label", "Upload")
      assert has_element?(lv, ~s(#portrait-form input[type=file][accept=".jpg,.jpeg,.png,.webp"]))
      refute has_element?(lv, "#remove-portrait")
    end

    test "uploads and replaces the portrait", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      upload_portrait(lv, "old.jpg")
      old = portrait(scope)
      assert %Feather.Media.Image{filename: "old.jpg"} = old
      assert has_element?(lv, ~s(#portrait-preview img[src*="#{old.public_id}"]))
      assert has_element?(lv, "#portrait-form label", "Replace")
      assert render(lv) =~ "Portrait was successfully updated."

      upload_portrait(lv, "new.jpg")

      assert %{filename: "new.jpg"} = new = portrait(scope)
      assert has_element?(lv, ~s(#portrait-preview img[src*="#{new.public_id}"]))
      refute Feather.Repo.get(Feather.Media.Image, old.id)
      refute has_element?(lv, "#mascot-footer-preview img")
    end

    test "removes the portrait after confirming", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")
      upload_portrait(lv)
      image = portrait(scope)

      html = confirm_click(lv, "#remove-portrait", "Remove the portrait?")

      assert html =~ "Portrait was successfully removed."
      assert portrait(scope) == nil
      refute Feather.Repo.get(Feather.Media.Image, image.id)
      refute has_element?(lv, "#portrait-preview img")
      refute has_element?(lv, "#remove-portrait")
    end

    test "shows an error for a file that is not an image", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      upload_portrait(lv, "fake.jpg", "not an image")

      assert has_element?(lv, "#portrait-error", "must be an image")
      assert portrait(scope) == nil
    end

    test "names the accepted formats for another file type", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      lv
      |> file_input("#portrait-form", :portrait_image, [
        %{name: "me.gif", content: "GIF89a", type: "image/gif"}
      ])
      |> render_upload("me.gif")

      lv |> element("#portrait-form") |> render_change(%{})

      assert has_element?(lv, "#portrait-error", "Only JPEG, PNG and WebP files can be uploaded.")
      assert portrait(scope) == nil
    end
  end

  describe "bio" do
    setup [:register_and_log_in_user, :create_site_for_user]

    test "shows an empty bio with a hint on the themes", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      assert has_element?(lv, "#bio-hint", "Simple sidebar theme shows it on every page")
      assert has_element?(lv, "#bio-form textarea#site_bio")
      refute has_element?(lv, "#site-form textarea")
    end

    test "saves, trims and clears the bio", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      html =
        lv
        |> form("#bio-form", site: %{bio: "  I build websites. Since 2001.  "})
        |> render_submit()

      assert html =~ "Site was successfully updated."
      assert has_element?(lv, "#site_bio", "I build websites. Since 2001.")
      assert Sites.get_site!(scope, site.public_id).bio == "I build websites. Since 2001."

      lv |> form("#bio-form", site: %{bio: " "}) |> render_submit()

      assert Sites.get_site!(scope, site.public_id).bio == nil
    end

    test "rejects a bio that is too long", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")
      bio = String.duplicate("a", 501)

      assert lv |> form("#bio-form", site: %{bio: bio}) |> render_change() =~
               "Should be at most 500 character(s)"

      lv |> form("#bio-form", site: %{bio: bio}) |> render_submit()

      assert Sites.get_site!(scope, site.public_id).bio == nil
    end

    test "saving the bio keeps the other settings", %{conn: conn, site: site, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/settings")

      lv |> form("#bio-form", site: %{bio: "Hello."}) |> render_submit()

      saved = Sites.get_site!(scope, site.public_id)
      assert saved.bio == "Hello."
      assert saved.title == site.title
      assert saved.domain == site.domain
    end
  end
end
