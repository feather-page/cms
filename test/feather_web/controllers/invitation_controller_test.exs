defmodule FeatherWeb.InvitationControllerTest do
  use FeatherWeb.ConnCase

  import Swoosh.TestAssertions

  alias Feather.{Accounts, Sites}

  setup do
    scope = site_scope_fixture(title: "Timon's Blog")
    invitation = invitation_fixture(scope, email: "invitee@example.com")
    %{scope: scope, invitation: invitation, token: Sites.invitation_token(invitation)}
  end

  defp expired_token(invitation) do
    Phoenix.Token.sign(FeatherWeb.Endpoint, "site invitation", invitation.id,
      signed_at: System.system_time(:second) - 8 * 24 * 60 * 60
    )
  end

  describe "GET /invitations/:token" do
    test "explains the invitation to a logged-out visitor", %{
      conn: conn,
      scope: scope,
      token: token
    } do
      conn = get(conn, ~p"/invitations/#{token}")
      html = html_response(conn, 200)

      assert html =~ "Welcome to feather.page"
      assert html =~ "Timon&#39;s Blog"
      assert html =~ scope.user.email
      assert html =~ ~s(action="/invitations/#{token}/accept")
    end

    test "is shown to the logged-in invitee", %{conn: conn, token: token} do
      conn = conn |> log_in_user(user_fixture(email: "invitee@example.com"))
      assert html_response(get(conn, ~p"/invitations/#{token}"), 200) =~ "Accept invitation"
    end

    test "redirects for an invalid token", %{conn: conn} do
      conn = get(conn, ~p"/invitations/forged")

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "The invitation link is invalid."
    end

    test "redirects for an expired token", %{conn: conn, invitation: invitation} do
      conn = get(conn, ~p"/invitations/#{expired_token(invitation)}")

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "has expired"
    end

    test "redirects for an accepted invitation", %{
      conn: conn,
      invitation: invitation,
      token: token
    } do
      {:ok, _} = Sites.accept_invitation(invitation, nil)

      conn = get(conn, ~p"/invitations/#{token}")

      assert redirected_to(conn) == ~p"/users/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You have already accepted the invitation."
    end

    test "redirects a revoked invitation", %{
      conn: conn,
      scope: scope,
      invitation: invitation,
      token: token
    } do
      {:ok, _} = Sites.delete_invitation(scope, invitation)

      conn = get(conn, ~p"/invitations/#{token}")
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "The invitation link is invalid."
    end

    test "refuses a logged-in user with another email", %{conn: conn, token: token} do
      conn = conn |> log_in_user(user_fixture()) |> get(~p"/invitations/#{token}")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "another email address"
    end
  end

  describe "POST /invitations/:token/accept" do
    test "creates the user, adds them to the site and logs them in", %{
      conn: conn,
      scope: scope,
      invitation: invitation,
      token: token
    } do
      conn = post(conn, ~p"/invitations/#{token}/accept")

      user = Accounts.get_user_by_email("invitee@example.com")
      assert user.confirmed_at
      assert Sites.member?(scope.site, user)
      assert Sites.list_pending_invitations(scope) == []
      refute Sites.get_invitation!(scope, invitation.id).accepted_at == nil

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == "/sites/#{scope.site.public_id}/posts"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "You have successfully accepted the invitation."

      assert_email_sent(
        to: [{"", scope.user.email}],
        subject: "The user invitee@example.com accepted your invitation to Timon's Blog."
      )

      # The new session works.
      conn = get(recycle(conn), ~p"/")
      assert html_response(conn, 200) =~ "invitee@example.com"
    end

    test "adds an existing user without creating another", %{
      conn: conn,
      scope: scope,
      token: token
    } do
      existing = user_fixture(email: "invitee@example.com")
      users = Feather.Repo.aggregate(Accounts.User, :count)

      conn = post(conn, ~p"/invitations/#{token}/accept")

      assert get_session(conn, :user_token)
      assert Sites.member?(scope.site, existing)
      assert Feather.Repo.aggregate(Accounts.User, :count) == users
    end

    test "works for the logged-in invitee", %{conn: conn, scope: scope, token: token} do
      invitee = user_fixture(email: "invitee@example.com")
      conn = conn |> log_in_user(invitee) |> post(~p"/invitations/#{token}/accept")

      assert redirected_to(conn) == "/sites/#{scope.site.public_id}/posts"
      assert Sites.member?(scope.site, invitee)
    end

    test "refuses a logged-in user with another email", %{
      conn: conn,
      scope: scope,
      token: token
    } do
      other = user_fixture()
      conn = log_in_user(conn, other)
      session_token = get_session(conn, :user_token)

      conn = post(conn, ~p"/invitations/#{token}/accept")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "another email address"
      # Still logged in as before, and nobody joined.
      assert get_session(conn, :user_token) == session_token
      refute Sites.member?(scope.site, other)
      refute Accounts.get_user_by_email("invitee@example.com")
      assert [_] = Sites.list_pending_invitations(scope)
      refute_email_sent()
    end

    test "refuses an accepted invitation", %{conn: conn, invitation: invitation, token: token} do
      {:ok, _} = Sites.accept_invitation(invitation, nil)

      conn = post(conn, ~p"/invitations/#{token}/accept")

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/users/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You have already accepted the invitation."
    end

    test "refuses an expired token", %{conn: conn, scope: scope, invitation: invitation} do
      conn = post(conn, ~p"/invitations/#{expired_token(invitation)}/accept")

      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "has expired"
      refute Accounts.get_user_by_email("invitee@example.com")
      assert [_] = Sites.list_pending_invitations(scope)
    end

    test "refuses an invalid token", %{conn: conn} do
      conn = post(conn, ~p"/invitations/forged/accept")

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "The invitation link is invalid."
    end
  end
end
