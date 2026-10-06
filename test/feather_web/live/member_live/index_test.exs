defmodule FeatherWeb.MemberLive.IndexTest do
  use FeatherWeb.ConnCase

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Feather.Sites
  alias Feather.Sites.Invitation

  test "a site the user is not a member of is not found", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    site = site_fixture()

    assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/sites/#{site.public_id}/users") end
  end

  describe "members" do
    setup [:register_and_log_in_user, :create_site_for_user]

    test "lists the members", %{conn: conn, site: site, scope: scope, user: user} do
      other = user_fixture()
      {:ok, other_member} = Sites.add_member(site, other)
      not_a_member = user_fixture()

      {:ok, lv, html} = live(conn, ~p"/sites/#{site.public_id}/users")

      own = Enum.find(Sites.list_members(scope), &(&1.user_id == user.id))
      assert has_element?(lv, "#member-#{own.id}", user.email)
      assert has_element?(lv, "#member-#{other_member.id}", other.email)
      refute html =~ not_a_member.email
    end

    test "removes another member but not oneself", %{
      conn: conn,
      site: site,
      scope: scope,
      user: user
    } do
      {:ok, other_member} = Sites.add_member(site, user_fixture())
      own = Enum.find(Sites.list_members(scope), &(&1.user_id == user.id))

      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/users")

      refute has_element?(lv, "#remove-member-#{own.id}")

      html = lv |> element("#remove-member-#{other_member.id}") |> render_click()

      assert html =~ "The user was successfully removed from the site."
      refute has_element?(lv, "#member-#{other_member.id}")
      assert [%{user_id: user_id}] = Sites.list_members(scope)
      assert user_id == user.id
    end

    test "refuses to remove oneself even when asked directly", %{
      conn: conn,
      site: site,
      scope: scope,
      user: user
    } do
      own = Enum.find(Sites.list_members(scope), &(&1.user_id == user.id))
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/users")

      assert render_hook(lv, "remove_member", %{"id" => own.id}) =~
               "You cannot remove yourself from the site."

      assert Sites.member?(site, user)
    end

    @tag :capture_log
    test "cannot remove a member of another site", %{conn: conn, site: site} do
      other_scope = site_scope_fixture()
      [other_member] = Sites.list_members(other_scope)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/users")

      Process.flag(:trap_exit, true)

      assert {{%Ecto.NoResultsError{}, _}, _} =
               catch_exit(render_hook(lv, "remove_member", %{"id" => other_member.id}))

      assert [_] = Sites.list_members(other_scope)
    end

    test "a super admin can remove members of any site", %{conn: conn} do
      site = site_fixture()
      [member] = Sites.list_members(Feather.Accounts.Scope.for_site(site))
      conn = log_in_user(conn, super_admin_fixture())

      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/users")
      lv |> element("#remove-member-#{member.id}") |> render_click()

      refute has_element?(lv, "#member-#{member.id}")
    end
  end

  describe "invitations" do
    setup [:register_and_log_in_user, :create_site_for_user]

    test "shows when there are no pending invitations", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/users")
      assert has_element?(lv, "#no-invitations")
    end

    test "invites a user by email", %{conn: conn, site: site, scope: scope, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/users")

      html =
        lv
        |> form("#invitation-form", invitation: %{email: "New@Example.com"})
        |> render_submit()

      assert html =~ "User was successfully invited."

      assert [%Invitation{email: "new@example.com"} = invitation] =
               Sites.list_pending_invitations(scope)

      assert invitation.inviting_user_id == user.id
      assert has_element?(lv, "#invitation-#{invitation.id}", "new@example.com")
      refute has_element?(lv, "#no-invitations")

      assert_email_sent(fn email ->
        assert email.to == [{"", "new@example.com"}]
        assert email.subject == "You have been invited to #{site.title} on feather.page"
        assert email.text_body =~ user.email
        [_, token] = Regex.run(~r{/invitations/(\S+)}, email.text_body)
        assert {:ok, %{id: id}} = Sites.get_invitation_by_token(token)
        assert id == invitation.id
      end)
    end

    # Rails: inviting an existing user creates an invitation, no second user.
    test "invites an existing user without creating another", %{
      conn: conn,
      site: site,
      scope: scope
    } do
      existing = user_fixture()
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/users")

      lv |> form("#invitation-form", invitation: %{email: existing.email}) |> render_submit()

      assert [%Invitation{}] = Sites.list_pending_invitations(scope)
      assert Feather.Repo.aggregate(Feather.Accounts.User, :count) == 2
    end

    test "shows errors for invalid emails and members", %{conn: conn, site: site, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/users")

      assert lv |> form("#invitation-form", invitation: %{email: "nope"}) |> render_change() =~
               "must have the @ sign and no spaces"

      assert lv
             |> form("#invitation-form", invitation: %{email: user.email})
             |> render_submit() =~ "is already a member of this site"

      refute_email_sent()
    end

    test "resends an invitation", %{conn: conn, site: site, scope: scope, user: user} do
      other_member = user_fixture()
      {:ok, _} = Sites.add_member(site, other_member)

      invitation =
        invitation_fixture(
          Feather.Accounts.Scope.put_site(Feather.Accounts.Scope.for_user(other_member), site),
          email: "pending@example.com"
        )

      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/users")

      html = lv |> element("#resend-invitation-#{invitation.id}") |> render_click()

      assert html =~ "Invitation was successfully resent."
      assert_email_sent(to: [{"", "pending@example.com"}])
      # The one resending becomes the inviter.
      assert Sites.get_invitation!(scope, invitation.id).inviting_user_id == user.id
    end

    test "revokes an invitation", %{conn: conn, site: site, scope: scope} do
      invitation = invitation_fixture(scope)
      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/users")

      html = lv |> element("#revoke-invitation-#{invitation.id}") |> render_click()

      assert html =~ "Invitation was successfully revoked."
      refute has_element?(lv, "#invitation-#{invitation.id}")
      assert Sites.list_pending_invitations(scope) == []
    end

    test "does not list accepted invitations", %{conn: conn, site: site, scope: scope} do
      invitation = invitation_fixture(scope)
      {:ok, _} = Sites.accept_invitation(invitation, nil)

      {:ok, lv, _html} = live(conn, ~p"/sites/#{site.public_id}/users")

      refute has_element?(lv, "#invitation-#{invitation.id}")
      assert has_element?(lv, "#no-invitations")
    end
  end
end
