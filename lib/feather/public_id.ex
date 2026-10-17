defmodule Feather.PublicId do
  @moduledoc """
  Public ids identify records in URLs, exported paths and the API.

  They are 12 characters from `0-9a-zA-Z` (no `_` or `-`, for nicer URLs).
  """

  @alphabet ~c"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
  @alphabet_size length(@alphabet)
  @alphabet_tuple List.to_tuple(@alphabet)
  @size 12
  # Largest multiple of the alphabet size below 256; bytes above it are
  # rejected so every character is equally likely.
  @limit div(256, @alphabet_size) * @alphabet_size

  @doc """
  Generates a new random public id.
  """
  @spec generate() :: String.t()
  def generate, do: generate(@size, [])

  defp generate(0, acc), do: List.to_string(acc)

  defp generate(remaining, acc) do
    {remaining, acc} =
      @size
      |> :crypto.strong_rand_bytes()
      |> :binary.bin_to_list()
      |> Enum.reduce_while({remaining, acc}, fn
        _byte, {0, acc} -> {:halt, {0, acc}}
        byte, {n, acc} when byte < @limit -> {:cont, {n - 1, [char(byte) | acc]}}
        _byte, state -> {:cont, state}
      end)

    generate(remaining, acc)
  end

  defp char(byte), do: elem(@alphabet_tuple, rem(byte, @alphabet_size))

  @doc "Puts a freshly generated public id into an insert changeset."
  @spec put(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def put(%Ecto.Changeset{} = changeset),
    do: Ecto.Changeset.put_change(changeset, :public_id, generate())
end
