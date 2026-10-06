defmodule Feather.Sites.InvitationNotifier do
  @moduledoc """
  Emails about site invitations.
  """

  import Swoosh.Email

  alias Feather.Mailer
  alias Feather.Sites.Invitation

  @doc """
  Invites the invitation's email address to the site. Expects `site` and
  `inviting_user` to be preloaded.
  """
  def deliver_invitation(%Invitation{} = invitation, accept_url) do
    deliver(
      invitation.email,
      "You have been invited to #{invitation.site.title} on feather.page",
      """

      ==============================

      Hi #{invitation.email},

      Someone invited you to join their site on feather.page:
      #{invitation.inviting_user.email} invited you to edit the website
      "#{invitation.site.title}" (#{invitation.site.domain}).

      Click the link below to accept the invitation:

      #{accept_url}

      The link is valid for 7 days. If you don't want to join, ignore this email.

      ==============================
      """
    )
  end

  @doc """
  Tells the inviting user that the invitation was accepted. Expects `site`
  and `inviting_user` to be preloaded.
  """
  def deliver_invitation_accepted(%Invitation{} = invitation) do
    deliver(
      invitation.inviting_user.email,
      "The user #{invitation.email} accepted your invitation to #{invitation.site.title}.",
      """

      ==============================

      Hi #{invitation.inviting_user.email},

      The user #{invitation.email} accepted your invitation to
      "#{invitation.site.title}".

      You can now collaborate on the site together.

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
