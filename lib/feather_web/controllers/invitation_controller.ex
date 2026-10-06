defmodule FeatherWeb.InvitationController do
  @moduledoc """
  Accepting a site invitation from the link in the invitation email.

  Works logged out: `show` explains which site the invitation is for and
  `accept` makes the invitee a member (creating their user if needed) and
  logs them in. A logged-in user can only accept invitations sent to their
  own email address.
  """
  use FeatherWeb, :controller

  alias Feather.Sites
  alias FeatherWeb.{SiteAuth, UserAuth}

  def show(conn, %{"token" => token}) do
    with {:ok, invitation} <- Sites.get_invitation_by_token(token),
         :ok <- check_email(conn, invitation) do
      invitation = Feather.Repo.preload(invitation, :inviting_user)
      render(conn, :show, invitation: invitation, token: token, page_title: "Invitation")
    else
      {:error, reason} -> reject(conn, reason)
    end
  end

  def accept(conn, %{"token" => token}) do
    with {:ok, invitation} <- Sites.get_invitation_by_token(token),
         {:ok, %{user: user, site: site}} <-
           Sites.accept_invitation(invitation, current_user(conn)) do
      conn
      |> put_flash(:info, "You have successfully accepted the invitation.")
      |> put_session(:user_return_to, SiteAuth.site_home_path(site))
      |> UserAuth.log_in_user(user)
    else
      {:error, reason} -> reject(conn, reason)
    end
  end

  defp current_user(conn) do
    case conn.assigns.current_scope do
      %{user: user} -> user
      nil -> nil
    end
  end

  defp check_email(conn, invitation) do
    case current_user(conn) do
      %{email: email} when email != invitation.email -> {:error, :email_mismatch}
      _ -> :ok
    end
  end

  defp reject(conn, reason) do
    conn
    |> put_flash(:error, message(reason))
    |> redirect(to: if(current_user(conn), do: ~p"/", else: ~p"/users/log-in"))
  end

  defp message(:already_accepted), do: "You have already accepted the invitation."
  defp message(:expired), do: "The invitation link has expired. Ask for a new invitation."

  defp message(:email_mismatch),
    do: "This invitation was sent to another email address. Log out to accept it."

  defp message(_reason), do: "The invitation link is invalid."
end
