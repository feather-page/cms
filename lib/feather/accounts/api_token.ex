defmodule Feather.Accounts.ApiToken do
  @moduledoc """
  A bearer token for the content API. Only the SHA-256 digest of the token is
  stored; the first characters are kept as a prefix to recognise it.
  """
  use Feather.Schema

  schema "api_tokens" do
    field :name, :string
    field :token_digest, :string, redact: true
    field :token_prefix, :string

    belongs_to :user, Feather.Accounts.User

    timestamps()
  end

  @doc """
  Builds a changeset for a new token and returns it with the plain token.
  """
  def build(user, name) do
    plain_token = 32 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)

    changeset =
      %__MODULE__{user_id: user.id}
      |> change(
        name: name,
        token_digest: digest(plain_token),
        token_prefix: binary_part(plain_token, 0, 8)
      )
      |> validate_length(:name, max: 255)
      |> unique_constraint(:token_digest)

    {plain_token, changeset}
  end

  def digest(plain_token), do: :crypto.hash(:sha256, plain_token) |> Base.encode16(case: :lower)
end
