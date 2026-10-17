defmodule Feather.SitesTest do
  use Feather.DataCase

  import Swoosh.TestAssertions

  alias Feather.{Content, Publishing, Sites}
  alias Feather.Accounts.Scope
  alias Feather.Sites.{Invitation, Site, SocialMediaService}

  describe "create_site/2" do
    test "creates the site, membership and homepage, but no deployment target" do
      user = user_fixture()
      scope = Scope.for_user(user)

      assert {:ok, %Site{} = site} =
               Sites.create_site(scope, %{
                 title: "Notes",
                 domain: "notes.example.com",
                 language_code: "de"
               })

      assert site.public_id =~ ~r/\A[0-9a-zA-Z]{12}\z/
      assert site.emoji == "🌐"
      assert site.copyright == "© All rights reserved."
      assert Sites.member?(site, user)

      site_scope = Scope.put_site(scope, site)
      homepage = Content.get_homepage(site_scope)
      assert homepage.title == "Home"
      assert homepage.slug == "/"
      assert Content.publication_status(homepage) == :published

      assert Publishing.list_targets(site_scope) == []
    end

    test "validates the site and creates nothing on error" do
      scope = user_scope_fixture()

      assert {:error, changeset} =
               Sites.create_site(scope, %{
                 title: "",
                 domain: "not a domain!",
                 language_code: "xx",
                 emoji: "abc",
                 copyright: ""
               })

      errors = errors_on(changeset)
      assert "can't be blank" in errors.title
      assert errors.domain != []
      assert "is invalid" in errors.language_code
      assert "must be an emoji" in errors.emoji
      # Ecto replaces empty values with the field default ("© All rights reserved.").
      refute Map.has_key?(errors, :copyright)

      assert Sites.list_sites(scope) == []
    end

    test "normalizes the domain like Rails' DomainNormalizer" do
      scope = user_scope_fixture()

      assert {:ok, site} =
               Sites.create_site(scope, %{
                 title: "X",
                 domain: " HTTPS://Blog.Example.com/posts/1 "
               })

      assert site.domain == "blog.example.com"
      assert Site.normalize_domain("http://example.com") == "example.com"
      assert Site.normalize_domain("example.com/") == "example.com"

      assert {:error, changeset} = Sites.create_site(scope, %{title: "X", domain: ""})
      assert "can't be blank" in errors_on(changeset).domain
    end

    test "requires a unique domain" do
      scope = user_scope_fixture()
      site_fixture(scope, domain: "taken.example.com")

      assert {:error, changeset} =
               Sites.create_site(scope, %{title: "X", domain: "taken.example.com"})

      assert "has already been taken" in errors_on(changeset).domain
    end
  end

  describe "access" do
    setup do
      owner = user_fixture()
      site = site_fixture(owner)
      %{owner: owner, site: site}
    end

    test "members see their sites", %{owner: owner, site: site} do
      scope = Scope.for_user(owner)
      assert [%Site{id: id}] = Sites.list_sites(scope)
      assert id == site.id
      assert Sites.get_site!(scope, site.public_id).id == site.id
      assert Sites.can_access_site?(scope, site)
    end

    test "lists sites by title, ignoring case", %{owner: owner} do
      site_fixture(owner, title: "Zipfelmaus")
      site_fixture(owner, title: "anton")

      titles = owner |> Scope.for_user() |> Sites.list_sites() |> Enum.map(& &1.title)
      assert titles == Enum.sort_by(titles, &String.downcase/1)
      assert List.first(titles) == "anton"
      assert List.last(titles) == "Zipfelmaus"
    end

    test "non-members get NoResultsError or nil", %{site: site} do
      scope = user_scope_fixture()
      assert Sites.list_sites(scope) == []
      assert Sites.get_site(scope, site.public_id) == nil
      refute Sites.can_access_site?(scope, site)

      assert_raise Ecto.NoResultsError, fn -> Sites.get_site!(scope, site.public_id) end
    end

    test "super admins see all sites", %{site: site} do
      scope = Scope.for_user(super_admin_fixture())
      assert [%Site{}] = Sites.list_sites(scope)
      assert Sites.get_site!(scope, site.public_id).id == site.id
      assert Sites.can_access_site?(scope, site)
    end

    test "update_site/3 refuses non-members", %{site: site} do
      assert_raise MatchError, fn ->
        Sites.update_site(user_scope_fixture(), site, %{title: "Hijacked"})
      end
    end

    test "update_site/3 updates", %{owner: owner, site: site} do
      assert {:ok, site} =
               Sites.update_site(Scope.for_user(owner), site, %{title: "New", emoji: "🪶"})

      assert site.title == "New"
      assert site.emoji == "🪶"
    end

    test "delete_site/2 deletes the site with its content", %{owner: owner, site: site} do
      scope = Scope.for_user(owner)
      image = image_fixture(Scope.put_site(scope, site))
      dir = Feather.Media.image_dir(image)
      assert File.dir?(dir)

      assert {:ok, _} = Sites.delete_site(scope, site)
      assert Sites.list_sites(scope) == []
      refute File.exists?(dir)
    end
  end

  describe "members" do
    test "add_member/2 is idempotent and remove_member/2 refuses self-removal" do
      scope = site_scope_fixture()
      other = user_fixture()

      assert {:ok, su} = Sites.add_member(scope.site, other)
      assert {:ok, su2} = Sites.add_member(scope.site, other)
      assert su.id == su2.id

      members = Sites.list_members(scope)
      assert length(members) == 2
      own = Enum.find(members, &(&1.user_id == scope.user.id))

      assert Sites.get_member!(scope, su.id).user.id == other.id
      assert_raise Ecto.NoResultsError, fn -> Sites.get_member!(site_scope_fixture(), su.id) end
      assert Sites.get_member(scope, su.id).user.id == other.id
      assert Sites.get_member(site_scope_fixture(), su.id) == nil

      assert {:error, :cannot_remove_self} = Sites.remove_member(scope, own)
      assert {:ok, _} = Sites.remove_member(scope, su)
      refute Sites.member?(scope.site, other)
    end
  end

  describe "invitations" do
    test "get_invitation/2 returns nil for a missing invitation or one of another site" do
      scope = site_scope_fixture()
      invitation = invitation_fixture(scope)
      assert Sites.get_invitation(scope, invitation.id).id == invitation.id
      assert Sites.get_invitation(site_scope_fixture(), invitation.id) == nil
      {:ok, _} = Sites.delete_invitation(scope, invitation)
      assert Sites.get_invitation(scope, invitation.id) == nil
    end

    setup do
      %{scope: site_scope_fixture()}
    end

    test "create_invitation/2 normalizes the email and rejects members", %{scope: scope} do
      assert {:ok, %Invitation{} = invitation} =
               Sites.create_invitation(scope, %{email: " New@Example.com "})

      assert invitation.email == "new@example.com"
      assert invitation.inviting_user_id == scope.user.id

      assert {:error, changeset} = Sites.create_invitation(scope, %{email: scope.user.email})
      assert "is already a member of this site" in errors_on(changeset).email

      assert {:error, changeset} = Sites.create_invitation(scope, %{email: "nope"})
      assert errors_on(changeset).email != []
    end

    test "inviting the same email again updates the pending invitation", %{scope: scope} do
      first = invitation_fixture(scope, email: "again@example.com")

      other_user = user_fixture()
      {:ok, _} = Sites.add_member(scope.site, other_user)
      other_scope = Scope.put_site(Scope.for_user(other_user), scope.site)

      assert {:ok, second} = Sites.create_invitation(other_scope, %{email: "again@example.com"})
      assert second.id == first.id
      assert second.inviting_user_id == other_user.id
      assert [_] = Sites.list_pending_invitations(scope)
    end

    test "the email is unique per site, not globally", %{scope: scope} do
      invitation_fixture(scope, email: "shared@example.com")
      other_scope = site_scope_fixture()
      assert {:ok, _} = Sites.create_invitation(other_scope, %{email: "shared@example.com"})
    end

    test "deliver_invitation/2 sends the acceptance link", %{scope: scope} do
      invitation = invitation_fixture(scope, email: "mail@example.com")

      {:ok, email} = Sites.deliver_invitation(invitation, &"https://cms.test/invitations/#{&1}")

      assert_email_sent(subject: "You have been invited to #{scope.site.title} on feather.page")
      assert email.to == [{"", "mail@example.com"}]
      assert email.from == {"Feather", "no-reply@feather.page"}
      assert email.text_body =~ "https://cms.test/invitations/"
    end

    test "accepting with a token creates the user and the membership", %{scope: scope} do
      invitation = invitation_fixture(scope, email: "invitee@example.com")
      token = Sites.invitation_token(invitation)

      assert {:ok, found} = Sites.get_invitation_by_token(token)
      assert found.id == invitation.id

      assert {:ok, %{user: user, site: site}} = Sites.accept_invitation(found, nil)
      assert user.email == "invitee@example.com"
      assert user.confirmed_at
      assert site.id == scope.site.id
      assert Sites.member?(scope.site, user)

      assert_email_sent(
        subject: "The user invitee@example.com accepted your invitation to #{scope.site.title}."
      )

      assert {:error, :already_accepted} = Sites.get_invitation_by_token(token)
      assert Sites.list_pending_invitations(scope) == []
    end

    test "an existing user accepts with their own account only", %{scope: scope} do
      invitee = user_fixture()
      invitation = invitation_fixture(scope, email: invitee.email)

      assert {:error, :email_mismatch} = Sites.accept_invitation(invitation, user_fixture())
      assert {:ok, %{user: user}} = Sites.accept_invitation(invitation, invitee)
      assert user.id == invitee.id
    end

    test "tokens are rejected when forged or expired", %{scope: scope} do
      invitation = invitation_fixture(scope)
      assert {:error, :invalid} = Sites.get_invitation_by_token("forged")

      expired =
        Phoenix.Token.sign(FeatherWeb.Endpoint, "site invitation", invitation.id,
          signed_at: System.system_time(:second) - 8 * 24 * 60 * 60
        )

      assert {:error, :expired} = Sites.get_invitation_by_token(expired)
    end

    test "sending an invitation again invalidates the links sent before", %{scope: scope} do
      invitation = invitation_fixture(scope, email: "again@example.com")
      first = Sites.invitation_token(invitation)

      {:ok, resent} = Sites.resend_invitation(scope, invitation, &"https://cms.test/#{&1}")
      second = Sites.invitation_token(resent)

      assert {:error, :invalid} = Sites.get_invitation_by_token(first)
      assert {:ok, _} = Sites.get_invitation_by_token(second)

      {:ok, reinvited} = Sites.create_invitation(scope, %{email: "again@example.com"})
      assert reinvited.id == invitation.id
      assert {:error, :invalid} = Sites.get_invitation_by_token(second)
      assert {:ok, _} = Sites.get_invitation_by_token(Sites.invitation_token(reinvited))
    end

    test "a removed member's old link does not work after a new invitation", %{scope: scope} do
      invitation = invitation_fixture(scope, email: "removed@example.com")
      old = Sites.invitation_token(invitation)
      {:ok, found} = Sites.get_invitation_by_token(old)
      {:ok, %{user: user}} = Sites.accept_invitation(found, nil)

      member = Enum.find(Sites.list_members(scope), &(&1.user_id == user.id))
      {:ok, _} = Sites.remove_member(scope, member)
      {:ok, reinvited} = Sites.create_invitation(scope, %{email: "removed@example.com"})

      assert {:error, :invalid} = Sites.get_invitation_by_token(old)
      assert {:ok, _} = Sites.get_invitation_by_token(Sites.invitation_token(reinvited))
    end

    test "resend and delete", %{scope: scope} do
      invitation = invitation_fixture(scope)
      assert {:ok, _} = Sites.resend_invitation(scope, invitation, &"https://cms.test/#{&1}")
      assert_email_sent()

      assert {:ok, _} = Sites.delete_invitation(scope, invitation)
      assert Sites.list_pending_invitations(scope) == []
    end
  end

  describe "social media links" do
    test "get_social_media_link/2 returns nil for a missing link or one of another site" do
      scope = site_scope_fixture()
      link = social_media_link_fixture(scope)
      assert Sites.get_social_media_link(scope, link.id).id == link.id
      assert Sites.get_social_media_link(site_scope_fixture(), link.id) == nil
      {:ok, _} = Sites.delete_social_media_link(scope, link)
      assert Sites.get_social_media_link(scope, link.id) == nil
    end

    test "the icon must be a known service" do
      scope = site_scope_fixture()

      assert {:error, changeset} =
               Sites.create_social_media_link(scope, %{
                 name: "MySpace",
                 url: "https://myspace.com/x",
                 icon: "myspace"
               })

      assert "is invalid" in errors_on(changeset).icon

      link = social_media_link_fixture(scope, icon: "mastodon", name: "Mastodon")
      assert [%{id: id}] = Sites.list_social_media_links(scope)
      assert id == link.id
      assert Sites.SocialMediaLink.svg(link) =~ "<svg"

      {:ok, _} = Sites.delete_social_media_link(scope, link)
      assert Sites.list_social_media_links(scope) == []
    end

    test "the service list matches the Rails list and has icons" do
      assert SocialMediaService.icons() ==
               ~w(facebook github gitlab instagram linkedin mastodon reddit rss vimeo whatsapp youtube)

      for service <- SocialMediaService.all() do
        assert service.url_placeholder =~ "://"
        assert SocialMediaService.svg(service.icon) =~ "<svg"
      end

      assert SocialMediaService.find("github").name == "GitHub"
    end
  end

  describe "navigation" do
    setup do
      scope = site_scope_fixture()
      pages = for title <- ~w(a b c), do: page_fixture(scope, title: title)
      %{scope: scope, pages: pages}
    end

    defp titles(scope), do: Enum.map(Sites.list_navigation_items(scope), & &1.page.title)
    defp positions(scope), do: Enum.map(Sites.list_navigation_items(scope), & &1.position)

    defp item(scope, title),
      do: Enum.find(Sites.list_navigation_items(scope), &(&1.page.title == title))

    test "add, move and remove keep positions contiguous", %{scope: scope, pages: [a, b, c]} do
      for page <- [a, b, c], do: {:ok, _} = Sites.add_to_navigation(scope, page)
      # Adding twice does not duplicate.
      {:ok, _} = Sites.add_to_navigation(scope, a)

      assert titles(scope) == ~w(a b c)
      assert positions(scope) == [1, 2, 3]

      :ok = Sites.move_navigation_item_down(scope, item(scope, "a"))
      assert titles(scope) == ~w(b a c)

      :ok = Sites.move_navigation_item_up(scope, item(scope, "c"))
      assert titles(scope) == ~w(b c a)

      # Moving beyond the ends is a no-op.
      :ok = Sites.move_navigation_item_up(scope, item(scope, "b"))
      :ok = Sites.move_navigation_item_down(scope, item(scope, "a"))
      assert titles(scope) == ~w(b c a)

      :ok = Sites.remove_from_navigation(scope, c)
      assert titles(scope) == ~w(b a)
      assert positions(scope) == [1, 2]
      assert Sites.in_navigation?(a)
      refute Sites.in_navigation?(c)
    end
  end

  describe "mascots" do
    setup do
      %{scope: site_scope_fixture()}
    end

    defp mascot_upload(scope, slot) do
      path = test_image_path(90, 30)
      {:ok, site} = Sites.put_mascot(scope, slot, path, "mascot.png")
      File.rm(path)
      site
    end

    test "there are three slots" do
      assert Sites.mascot_slots() == [:footer, :post_end, :projects]
    end

    test "put_mascot/4 stores the upload as the slot's image", %{scope: scope} do
      path = test_image_path(90, 30)

      assert {:ok, %Site{} = site} = Sites.put_mascot(scope, :footer, path, "mice.png")

      assert %Feather.Media.Image{filename: "mice.png"} = image = site.footer_mascot_image
      assert image.site_id == scope.site.id
      assert site.footer_mascot_image_id == image.id
      assert site.post_end_mascot_image == nil
      assert site.projects_mascot_image == nil
      assert Repo.get!(Site, scope.site.id).footer_mascot_image_id == image.id
    end

    test "put_mascot/4 replaces the slot's image and deletes the old one", %{scope: scope} do
      old = mascot_upload(scope, :post_end).post_end_mascot_image
      new = mascot_upload(scope, :post_end).post_end_mascot_image

      assert new.id != old.id
      assert Repo.get!(Site, scope.site.id).post_end_mascot_image_id == new.id
      refute Repo.get(Feather.Media.Image, old.id)
      refute File.exists?(Feather.Media.image_dir(old))
    end

    test "put_mascot/4 leaves the slot alone when the file is not an image", %{scope: scope} do
      image = mascot_upload(scope, :projects).projects_mascot_image
      path = Path.join(System.tmp_dir!(), "not-an-image-#{System.unique_integer([:positive])}")
      File.write!(path, "no image")

      assert {:error, %Ecto.Changeset{} = changeset} =
               Sites.put_mascot(scope, :projects, path, "fake.png")

      assert {"must be an image", _} = changeset.errors[:file]
      assert Repo.get!(Site, scope.site.id).projects_mascot_image_id == image.id
    end

    test "remove_mascot/2 clears the slot and deletes the image", %{scope: scope} do
      image = mascot_upload(scope, :footer).footer_mascot_image
      _other = mascot_upload(scope, :projects)

      assert {:ok, site} = Sites.remove_mascot(scope, :footer)

      assert site.footer_mascot_image == nil
      assert site.projects_mascot_image
      assert Repo.get!(Site, scope.site.id).footer_mascot_image_id == nil
      refute Repo.get(Feather.Media.Image, image.id)
      refute File.exists?(Feather.Media.image_dir(image))
    end

    test "a mascot image that is also a post header survives replace and remove", %{
      scope: scope
    } do
      replaced = mascot_upload(scope, :footer).footer_mascot_image
      post_fixture(scope, %{header_image_id: replaced.id})
      removed = mascot_upload(scope, :footer).footer_mascot_image
      post_fixture(scope, %{header_image_id: removed.id})

      assert {:ok, %Site{footer_mascot_image: nil}} = Sites.remove_mascot(scope, :footer)

      for image <- [replaced, removed] do
        assert Repo.get(Feather.Media.Image, image.id)
        assert File.exists?(Feather.Media.image_dir(image))
      end
    end

    test "remove_mascot/2 on an empty slot does nothing", %{scope: scope} do
      assert {:ok, %Site{footer_mascot_image: nil}} = Sites.remove_mascot(scope, :footer)
    end

    test "non-members may not change mascots", %{scope: scope} do
      path = test_image_path()
      stranger = Scope.put_site(user_scope_fixture(), scope.site)

      assert_raise MatchError, fn -> Sites.put_mascot(stranger, :footer, path, "x.png") end
      assert_raise MatchError, fn -> Sites.remove_mascot(stranger, :footer) end
      assert Feather.Media.list_images(scope) == []
    end

    test "the site form cannot set mascots", %{scope: scope} do
      image = image_fixture(scope)

      {:ok, site} =
        Sites.update_site(scope, scope.site, %{
          "footer_mascot_image_id" => image.id,
          "post_end_mascot_image_id" => image.id,
          "projects_mascot_image_id" => image.id
        })

      assert site.footer_mascot_image_id == nil
      assert site.post_end_mascot_image_id == nil
      assert site.projects_mascot_image_id == nil
    end

    test "deleting a mascot image clears the slot", %{scope: scope} do
      image = mascot_upload(scope, :footer).footer_mascot_image

      {:ok, _} = Feather.Media.delete_image(image)

      assert Repo.get!(Site, scope.site.id).footer_mascot_image_id == nil
    end

    test "a site with mascots can be deleted", %{scope: scope} do
      image = mascot_upload(scope, :footer).footer_mascot_image

      assert {:ok, _} = Sites.delete_site(scope, scope.site)
      refute Repo.get(Site, scope.site.id)
      refute File.exists?(Feather.Media.image_dir(image))
    end
  end

  describe "theme" do
    setup do
      %{scope: site_scope_fixture()}
    end

    test "a new site uses the feather theme", %{scope: scope} do
      assert Repo.get!(Site, scope.site.id).theme == "feather"
    end

    test "every member may choose a registered theme", %{scope: scope} do
      member = user_fixture()
      {:ok, _} = Sites.add_member(scope.site, member)
      member_scope = Scope.put_site(user_scope_fixture(member), scope.site)

      assert {:ok, %Site{theme: "simple_sidebar"}} =
               Sites.update_site(member_scope, scope.site, %{"theme" => "simple_sidebar"})
    end

    test "rejects themes that are not registered", %{scope: scope} do
      assert {:error, changeset} = Sites.update_site(scope, scope.site, %{"theme" => "nope"})
      assert {"is invalid", _} = changeset.errors[:theme]
    end
  end

  describe "portrait" do
    setup do
      %{scope: site_scope_fixture()}
    end

    defp portrait_upload(scope) do
      path = test_image_path(60, 80, "jpg")
      {:ok, site} = Sites.put_portrait(scope, path, "me.jpg")
      File.rm(path)
      site
    end

    test "put_portrait/3 stores the upload as the site's portrait", %{scope: scope} do
      path = test_image_path(60, 80, "jpg")

      assert {:ok, %Site{} = site} = Sites.put_portrait(scope, path, "me.jpg")

      assert %Feather.Media.Image{filename: "me.jpg"} = image = site.portrait_image
      assert image.site_id == scope.site.id
      assert site.footer_mascot_image == nil
      assert Repo.get!(Site, scope.site.id).portrait_image_id == image.id
    end

    test "put_portrait/3 replaces the portrait and deletes the old one", %{scope: scope} do
      old = portrait_upload(scope).portrait_image
      new = portrait_upload(scope).portrait_image

      assert new.id != old.id
      assert Repo.get!(Site, scope.site.id).portrait_image_id == new.id
      refute Repo.get(Feather.Media.Image, old.id)
      refute File.exists?(Feather.Media.image_dir(old))
    end

    test "put_portrait/3 keeps the portrait when the file is not an image", %{scope: scope} do
      image = portrait_upload(scope).portrait_image
      path = Path.join(System.tmp_dir!(), "not-an-image-#{System.unique_integer([:positive])}")
      File.write!(path, "no image")

      assert {:error, %Ecto.Changeset{} = changeset} = Sites.put_portrait(scope, path, "x.jpg")
      assert {"must be an image", _} = changeset.errors[:file]
      assert Repo.get!(Site, scope.site.id).portrait_image_id == image.id
    end

    test "remove_portrait/1 clears the portrait and deletes the image", %{scope: scope} do
      image = portrait_upload(scope).portrait_image
      path = test_image_path()
      {:ok, _} = Sites.put_mascot(scope, :footer, path, "mascot.png")

      assert {:ok, site} = Sites.remove_portrait(scope)

      assert site.portrait_image == nil
      assert site.footer_mascot_image
      assert Repo.get!(Site, scope.site.id).portrait_image_id == nil
      refute Repo.get(Feather.Media.Image, image.id)
    end

    test "non-members may not change the portrait", %{scope: scope} do
      path = test_image_path()
      stranger = Scope.put_site(user_scope_fixture(), scope.site)

      assert_raise MatchError, fn -> Sites.put_portrait(stranger, path, "x.png") end
      assert_raise MatchError, fn -> Sites.remove_portrait(stranger) end
      assert Feather.Media.list_images(scope) == []
    end

    test "the site form cannot set the portrait", %{scope: scope} do
      image = image_fixture(scope)

      {:ok, site} = Sites.update_site(scope, scope.site, %{"portrait_image_id" => image.id})

      assert site.portrait_image_id == nil
    end

    test "deleting the portrait image clears it", %{scope: scope} do
      image = portrait_upload(scope).portrait_image

      {:ok, _} = Feather.Media.delete_image(image)

      assert Repo.get!(Site, scope.site.id).portrait_image_id == nil
    end
  end
end
