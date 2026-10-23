defmodule Feather.OAuth.AuthorizationCode do
  @moduledoc """
  A code the authorization endpoint hands a client after the member allowed
  it, to be exchanged once for tokens before `expires_at`. Only the code's
  SHA-256 digest is stored, with the PKCE challenge the client sent.
  """
  use Feather.Schema

  @type t :: %__MODULE__{}

  schema "authorization_codes" do
    field :code_digest, :string, redact: true
    field :client_id, :string
    field :client_name, :string
    field :redirect_uri, :string
    field :code_challenge, :string
    field :expires_at, :utc_datetime_usec

    belongs_to :user, Feather.Accounts.User

    timestamps(updated_at: false)
  end
end
