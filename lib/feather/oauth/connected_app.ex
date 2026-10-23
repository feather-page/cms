defmodule Feather.OAuth.ConnectedApp do
  @moduledoc """
  An MCP client a member allowed to work on their sites, with the digests
  of its current access and refresh token. `inserted_at` is when the member
  connected it; it expires when unused for 90 days (`Feather.OAuth`).
  """
  use Feather.Schema

  @type t :: %__MODULE__{}

  schema "connected_apps" do
    field :client_id, :string
    field :client_name, :string
    field :access_token_digest, :string, redact: true
    field :access_token_expires_at, :utc_datetime_usec
    field :refresh_token_digest, :string, redact: true
    field :last_used_at, :utc_datetime_usec

    belongs_to :user, Feather.Accounts.User

    timestamps()
  end
end
