defmodule Feather.Content.ShortPost do
  @moduledoc """
  A short post is a post without a title (ADR 0026). Its `meta_title`
  names it in the document title, `og:title` and the feeds, but neither on
  the site nor in the CMS's post list.

  At its first publish, when it has no slug, the model writes the meta
  title and the slug (`needed?/2`); afterwards the slug never changes.
  """

  alias Feather.Content.{Blocks, Post, Slug}
  alias Feather.Ollama
  alias Feather.Validations

  @model_text_length 6000
  @max_slug_length 60

  @doc """
  Whether publishing the post needs a meta title and slug, given its
  newest version (nil if it has none): a short post without a slug at its
  first publish.
  """
  @spec needed?(map(), map() | nil) :: boolean()
  def needed?(%Post{slug: nil, title: title}, nil), do: Validations.blank?(title)
  def needed?(_record, _newest_version), do: false

  @doc """
  Asks the model for the meta title of a short post and the base of its
  slug (e.g. `"e-ink-solar-dashboard"`, `""` if neither the model's slug
  nor its title gives one), in the language with the given code. Returns
  `{:error, reason}` without a model, when it fails or for a post without
  text.
  """
  @spec generate(Post.t(), String.t()) ::
          {:ok, %{meta_title: String.t(), slug: String.t()}} | {:error, term()}
  def generate(%Post{content: content}, language_code) do
    with text when text != "" <- Blocks.excerpt(content, @model_text_length),
         {:ok, %{title: title, slug: slug}} <- Ollama.short_post_title(text, language_code) do
      {:ok, %{meta_title: title, slug: slug_base(slug, title)}}
    else
      "" -> {:error, :no_text}
      {:error, reason} -> {:error, reason}
    end
  end

  defp slug_base(slug, title) do
    case clean_slug(slug) do
      "" -> clean_slug(title)
      base -> base
    end
  end

  defp clean_slug(text) do
    base = text |> Slug.from_title() |> String.trim("/") |> String.trim("-")

    if String.length(base) > @max_slug_length,
      do: base |> String.slice(0, @max_slug_length) |> String.replace(~r/-[^-]*\z/, ""),
      else: base
  end
end
