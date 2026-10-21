defmodule Feather.Content.Description do
  @moduledoc """
  The description of a post or page: the sentence search results and link
  previews show (ADR 0026). `description_generated` marks one the model
  wrote; editing the description clears it.

  Publishing asks the model for a description when the record has none, or
  when its description was generated and its title or content changed
  since its newest version (`needed?/2`).
  """

  import Ecto.Changeset

  alias Feather.Content.Blocks
  alias Feather.Ollama
  alias Feather.Validations

  @model_text_length 6000

  @doc "Casts the description of a post or page changeset; a changed one is no longer generated."
  @spec cast_description(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def cast_description(changeset) do
    changeset = Validations.trim_to_nil(changeset, :description)

    if changed?(changeset, :description),
      do: put_change(changeset, :description_generated, false),
      else: changeset
  end

  @doc """
  Whether publishing the post or page needs a new description, given its
  newest version (nil if it has none).
  """
  @spec needed?(map(), map() | nil) :: boolean()
  def needed?(%{description: description} = record, newest_version) do
    Validations.blank?(description) or
      (record.description_generated and changed_since?(record, newest_version))
  end

  defp changed_since?(_record, nil), do: false

  defp changed_since?(record, version),
    do: record.title != version.title or record.content != version.content

  @doc """
  Asks the model for a description of the post or page in the language
  with the given code. Returns `{:error, reason}` without a model, when it
  fails or for a record without text.
  """
  @spec generate(map(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def generate(%{title: title, content: content}, language_code) do
    case Blocks.excerpt(content, @model_text_length) do
      "" -> {:error, :no_text}
      text -> Ollama.description(title, text, language_code)
    end
  end
end
