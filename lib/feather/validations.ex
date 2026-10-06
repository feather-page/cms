defmodule Feather.Validations do
  @moduledoc """
  Changeset validations shared by several schemas.
  """

  import Ecto.Changeset

  @emoji_regex ~r/\A[\p{Emoji}\x{1F3FB}-\x{1F3FF}\x{200D}\x{FE0F}]+\z/u

  @doc """
  Returns true if the value consists only of emoji characters (including
  skin tone modifiers, zero-width joiners and variation selectors).
  """
  @spec emoji?(term()) :: boolean()
  def emoji?(value) when is_binary(value), do: Regex.match?(@emoji_regex, value)
  def emoji?(_value), do: false

  @doc """
  Validates that the field is blank or only contains emoji.
  """
  @spec validate_emoji(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def validate_emoji(changeset, field) do
    validate_change(changeset, field, fn ^field, value ->
      if blank?(value) or emoji?(value), do: [], else: [{field, "must be an emoji"}]
    end)
  end

  @doc """
  Trims a string field and turns blank values into nil.
  """
  @spec trim_to_nil(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def trim_to_nil(changeset, field) do
    update_change(changeset, field, fn
      value when is_binary(value) ->
        case String.trim(value) do
          "" -> nil
          trimmed -> trimmed
        end

      value ->
        value
    end)
  end

  @doc """
  Returns true for nil and whitespace-only strings.
  """
  @spec blank?(term()) :: boolean()
  def blank?(nil), do: true
  def blank?(value) when is_binary(value), do: String.trim(value) == ""
  def blank?(_value), do: false
end
