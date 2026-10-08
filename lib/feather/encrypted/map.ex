defmodule Feather.Encrypted.Map do
  @moduledoc """
  An Ecto type for a map stored as encrypted JSON in a binary column.

  The map is JSON encoded and encrypted with `Feather.Encryption` on dump and
  decrypted on load, so the column never holds plaintext.

  A value that does not decrypt (the key changed) fails to load, with an
  error logged, rather than loading as an empty map: an empty map could be
  saved back over credentials that the right key still decrypts, and a
  deploy with it would fail in confusing ways. Code that only needs a
  target's metadata does not select the column (see
  `Feather.Publishing.list_targets/1`), so a wrong key only breaks editing
  and deploying a target.
  """

  use Ecto.Type

  require Logger

  @impl true
  def type, do: :binary

  @impl true
  def cast(nil), do: {:ok, %{}}
  def cast(%{} = map), do: {:ok, stringify_keys(map)}
  def cast(_other), do: :error

  @impl true
  def dump(nil), do: {:ok, nil}

  def dump(%{} = map) do
    {:ok, map |> stringify_keys() |> Jason.encode!() |> Feather.Encryption.encrypt()}
  end

  def dump(_other), do: :error

  @impl true
  def load(nil), do: {:ok, %{}}

  def load(binary) when is_binary(binary) do
    with {:ok, json} <- Feather.Encryption.decrypt(binary),
         {:ok, %{} = map} <- Jason.decode(json) do
      {:ok, map}
    else
      _ ->
        Logger.error(
          "Could not decrypt an encrypted map (deployment target config). " <>
            "Was CONFIG_ENCRYPTION_KEY changed?"
        )

        :error
    end
  end

  @impl true
  def equal?(a, b), do: a == b

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end
end
