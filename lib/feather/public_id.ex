defmodule Feather.PublicId do
  @moduledoc """
  Public ids identify records in URLs, exported paths and the API.

  They are 12 characters from `0-9a-zA-Z` (no `_` or `-`, for nicer URLs),
  the same alphabet and length as the Rails app, so imported ids stay valid.
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

  @doc """
  Returns true if the string looks like a public id.
  """
  @spec valid?(term()) :: boolean()
  def valid?(value) when is_binary(value), do: value =~ ~r/\A[0-9a-zA-Z]{12}\z/
  def valid?(_value), do: false

  @doc """
  Puts a freshly generated public id into an insert changeset unless one is
  already set (imports keep their existing ids).
  """
  @spec put_new(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def put_new(%Ecto.Changeset{} = changeset) do
    case Ecto.Changeset.get_field(changeset, :public_id) do
      nil -> Ecto.Changeset.put_change(changeset, :public_id, generate())
      _ -> changeset
    end
  end
end
