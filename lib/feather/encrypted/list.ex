defmodule Feather.Encrypted.List do
  @moduledoc """
  An Ecto type for a list stored as encrypted JSON in a binary column, like
  `Feather.Encrypted.Map` for maps. nil loads as an empty list; a value
  that does not decrypt fails to load, with an error logged.
  """

  use Ecto.Type

  require Logger

  @impl true
  def type, do: :binary

  @impl true
  def cast(nil), do: {:ok, []}
  def cast(list) when is_list(list), do: {:ok, list}
  def cast(_other), do: :error

  @impl true
  def dump(nil), do: {:ok, nil}

  def dump(list) when is_list(list),
    do: {:ok, list |> Jason.encode!() |> Feather.Encryption.encrypt()}

  def dump(_other), do: :error

  @impl true
  def load(nil), do: {:ok, []}

  def load(stored) when is_binary(stored) do
    with {:ok, json} <- Feather.Encryption.decrypt(stored),
         {:ok, list} when is_list(list) <- Jason.decode(json) do
      {:ok, list}
    else
      _invalid ->
        Logger.error("Could not decrypt an encrypted list. Was CONFIG_ENCRYPTION_KEY changed?")
        :error
    end
  end
end
