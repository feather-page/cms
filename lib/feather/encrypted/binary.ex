defmodule Feather.Encrypted.Binary do
  @moduledoc """
  An Ecto type for a binary stored encrypted with `Feather.Encryption` in
  a binary column: a secret, such as a private key, or content kept from
  the database in clear text, such as a mention's.

  A value that does not decrypt (the key changed) fails to load, with an
  error logged, rather than loading as nil, which could be saved back over
  the value the right key still decrypts. A secret is not loaded with its
  record (`load_in_query: false`); content that every use shows is.
  """

  use Ecto.Type

  require Logger

  @impl true
  def type, do: :binary

  @impl true
  def cast(nil), do: {:ok, nil}
  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(_other), do: :error

  @impl true
  def dump(nil), do: {:ok, nil}
  def dump(value) when is_binary(value), do: {:ok, Feather.Encryption.encrypt(value)}
  def dump(_other), do: :error

  @impl true
  def load(nil), do: {:ok, nil}

  def load(stored) when is_binary(stored) do
    case Feather.Encryption.decrypt(stored) do
      {:ok, value} ->
        {:ok, value}

      :error ->
        Logger.error("Could not decrypt an encrypted secret. Was CONFIG_ENCRYPTION_KEY changed?")
        :error
    end
  end
end
