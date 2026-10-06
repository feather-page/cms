defmodule Feather.Content.Tags do
  @moduledoc """
  Tags are stored as one comma separated string, normalized to lowercase,
  trimmed and unique: `"Elixir, phoenix ,elixir"` becomes
  `"elixir, phoenix"`. Blank tags become nil.
  """

  import Ecto.Changeset

  @doc "Normalizes a tag string."
  @spec normalize(String.t() | nil) :: String.t() | nil
  def normalize(nil), do: nil

  def normalize(tags) when is_binary(tags) do
    case parse(tags, &String.downcase/1) do
      [] -> nil
      list -> Enum.join(list, ", ")
    end
  end

  @doc "Normalizes the `:tags` field of a changeset."
  @spec cast_tags(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def cast_tags(changeset), do: update_change(changeset, :tags, &normalize/1)

  @doc """
  The tags of a record (or a tag string) as a list.
  """
  @spec tag_list(%{tags: String.t() | nil} | String.t() | nil) :: [String.t()]
  def tag_list(%{tags: tags}), do: tag_list(tags)
  def tag_list(nil), do: []
  def tag_list(tags) when is_binary(tags), do: parse(tags, & &1)

  @doc "Joins a list of tags into the stored form."
  @spec from_list([String.t()]) :: String.t() | nil
  def from_list(list) when is_list(list), do: list |> Enum.join(", ") |> normalize()

  defp parse(tags, transform) do
    tags
    |> String.split(",")
    |> Enum.map(&(&1 |> String.trim() |> transform.()))
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end
end
