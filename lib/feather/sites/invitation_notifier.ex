defmodule Feather.Sites.InvitationNotifier do
  @moduledoc """
  Emails about site invitations.
  """

  import Swoosh.Email

  alias Feather.Mailer
  alias Feather.Sites.Invitation

  @doc """
  Invites the invitation's email address to the site.
  """
  def deliver_invitation(%Invitation{} = invitation, accept_url) do
    deliver(invitation.email, "You have been invited to #{invitation.site.title}", """

    ==============================

    Hi #{invitation.email},

    #{invitation.inviting_user.email} invited you to edit the website
    "#{invitation.site.title}" (#{invitation.site.domain}).

    Accept the invitation by visiting the URL below:

    #{accept_url}

    The link is valid for 7 days. If you don't want to join, ignore this email.

    ==============================
    """)
  end

  @doc """
  Tells the inviting user that the invitation was accepted.
  """
  def deliver_invitation_accepted(%Invitation{} = invitation) do
    deliver(
      invitation.inviting_user.email,
      "#{invitation.email} accepted your invitation",
      """

      ==============================

      Hi #{invitation.inviting_user.email},

      #{invitation.email} accepted your invitation and can now edit
      "#{invitation.site.title}".

      ==============================
      """
    )
  end

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from(Mailer.from())
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end
end
