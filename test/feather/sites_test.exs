defmodule Feather.SitesTest do
  use Feather.DataCase

  import Swoosh.TestAssertions

  alias Feather.{Content, Publishing, Sites}
  alias Feather.Accounts.Scope
  alias Feather.Sites.{Invitation, Site, SocialMediaService}

  describe "create_site/2" do
    test "creates the site, membership, homepage and staging target" do
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

      assert [target] = Publishing.list_targets(site_scope)
      assert target.type == "staging"
      assert target.provider == "internal"

      assert target.public_hostname ==
               "#{String.downcase(site.public_id)}.stage.#{Application.fetch_env!(:feather, :staging_host)}"
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

      assert {:error, :cannot_remove_self} = Sites.remove_member(scope, own)
      assert {:ok, _} = Sites.remove_member(scope, su)
      refute Sites.member?(scope.site, other)
    end
  end

  describe "invitations" do
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

      assert_email_sent(subject: "You have been invited to #{scope.site.title}")
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

      assert_email_sent(subject: "invitee@example.com accepted your invitation")

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

    test "resend and delete", %{scope: scope} do
      invitation = invitation_fixture(scope)
      assert {:ok, _} = Sites.resend_invitation(scope, invitation, &"https://cms.test/#{&1}")
      assert_email_sent()

      assert {:ok, _} = Sites.delete_invitation(scope, invitation)
      assert Sites.list_pending_invitations(scope) == []
    end
  end

  describe "social media links" do
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

      {:ok, link} = Sites.update_social_media_link(scope, link, %{url: "https://x.social/@me"})
      assert link.url == "https://x.social/@me"
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
end
